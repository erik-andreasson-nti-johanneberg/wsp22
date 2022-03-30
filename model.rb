module Model

    # Connects to the db with the results as a hash
    #
    # @return [db] db variable containing the db 
    def connect_to_db_with_hash()
        db = SQLite3::Database.new("db/goodgames.db")
        db.results_as_hash = true
        return db
    end

    # Connects to the db with the results not as a hash
    #
    # @return [db] db variable containing the db 
    def connect_to_db_no_hash()
        db = SQLite3::Database.new("db/goodgames.db")
        return db
    end

    # Retrieves the games from the genres action and racing
    #
    # @return [Array] 
    #   * [Hash] Contains all the information from all the games in the action genre
    #   * [Hash] Contains all the information from all the games in the racing genre
    def home_page_games(db)
        action_games = db.execute("SELECT * FROM game WHERE id IN (SELECT game_id FROM genre_relation WHERE genre_id = 1)")
        racing_games = db.execute("SELECT * FROM game WHERE id IN (SELECT game_id FROM genre_relation WHERE genre_id = 24)")
        return [action_games, racing_games]
    end

    # Retrieves all the information of a specific game
    #
    # @return [Hash] Information of the game selected
    def all_game_info(db, game_name)
        return db.execute("SELECT * FROM game WHERE name = ?",game_name).first
    end

    # Retrieves information from the database in order to create the add a game page
    #
    # @return [Array] 
    #   * [Hash] All available publisher names
    #   * [Hash] All available genre names
    #   * [Hash] Admin control number
    #   * [Hash] All available game names
    def add_game(db)
        publisher_names = db.execute("SELECT name FROM publisher")
        genres = db.execute("SELECT name FROM genre")
        admin = db.execute("SELECT admin FROM user WHERE id = ?", session[:id]).first
        games = db.execute("SELECT name FROM game")
        return [publisher_names, genres, admin, games]
    end

    # Retrieves information from the database in order to create the add a publisher page
    #
    # @return [Array] 
    #   * [Hash] Admin control number
    #   * [Hash] All available publisher names
    def add_publisher(db)
        admin = db.execute("SELECT admin FROM user WHERE id = ?", session[:id]).first
        publishers = db.execute("SELECT name FROM publisher")
        return [admin, publishers]
    end

    # Retrieves information from the database in order to make the game_page. Also corrects incorrect publisher information for games in the database
    #
    # @return [Array]
    #   * [Hash] Name of the publisher attributed to the selected game
    #   * [Hash] Information from the database pertaining to the selected game
    #   * [Hash] Information from the database pertaining to the reviews of the selected game
    #   * [Hash] Ratings from reviews attributed to the selected game
    def game_page(db, game_name)
        game_id = db.execute("SELECT id FROM game WHERE name=?", game_name).first
        game_id = game_id["id"]
        publisher_name = db.execute("SELECT name FROM publisher WHERE id IN (SELECT publisher_id FROM game WHERE name = ?)",game_name).first
        if publisher_name != db.execute("SELECT publisher_name FROM game WHERE publisher_name = ?", game_name)
        end
        begin 
            if publisher_name != db.execute("SELECT publisher_name FROM game WHERE name = ?", game_name)
                publisher_name = db.execute("SELECT name FROM publisher WHERE name IN (SELECT publisher_name FROM game WHERE id = ?)", game_id).first
                new_id = db.execute("SELECT id FROM publisher WHERE name = ?", publisher_name["name"]).first
                db.execute("UPDATE game SET publisher_id = ? WHERE publisher_name = ?",new_id['id'], publisher_name["name"])
                publisher_name = db.execute("SELECT name FROM publisher WHERE id IN (SELECT publisher_id FROM game WHERE name = ?)",game_name).first
            end
        rescue
            publisher_name = {"name"=>"Not found or deleted"}
        ensure
            game_info = db.execute("SELECT * FROM game WHERE name = ?",game_name).first
            reviews = db.execute("SELECT * FROM review WHERE game_id = ?", game_id)
            ratings = db.execute("SELECT rating FROM review WHERE game_id = ?", game_id)
        end
        return [publisher_name, game_info, reviews, ratings]
    end

    # Information from the database in order to create the publisher page
    #
    # @return [Hash] All information in the database pertaining to publishers
    def show_publishers(db)
        return db.execute("SELECT * FROM publisher")
    end

    # Information from the database in order to create the profile page
    #
    # @return [Array]
    #   * [Hash] Information from the database pertaining to the logged in user
    #   * [Hash] Information for all the reviews that the logged in user has published
    #   * [Integer] The number of hours the logged in user has played games they have reviewed 
    def profile_page(db)
        profile_info = db.execute("SELECT * FROM user WHERE username = ?", session[:username]).first
        reviews = db.execute("SELECT * FROM review WHERE username = ?", session[:username])
        hrs_played_hash = db.execute("SELECT hrs_played FROM review WHERE username = ?", session[:username])
        hours = 0
        hrs_played_hash.each do |hrs|
            hours += hrs["hrs_played"].to_i
        end
        return [profile_info, reviews, hours]
    end

    # Inserts a review into the database
    #
    def add_review(db, finished_q, game_name, rating, review, review_date, hrs_played)
        db.execute("UPDATE user SET games_reviewed = games_reviewed + 1 WHERE username = ?", session[:username])
        if finished_q
            finished = 1
            db.execute("UPDATE user SET games_played = games_played + 1 WHERE username = ?", session[:username])
        else
            finished = 0
        end
        game_id = db.execute("SELECT id FROM game WHERE name = ?", game_name)
        db.execute("INSERT INTO review (rating, username, comments, review_date, game_id, finished, hrs_played) VALUES (?,?,?,?,?,?,?)",rating, session[:username], review, review_date, game_id, finished, hrs_played)
    end

    # Attempts to create an account and add it into the database
    #
    # Redirect to home page if account creation successfull
    # Redirect to error page if passwords do not match
    # Redirect to error page if username already exists
    def account_creation(db, password, password_confirm, username, email, age, date, admin_passkey)
        if db.execute("SELECT COUNT(1) FROM user WHERE username = ?", username).first["COUNT(1)"] < 1
            result = db.execute("SELECT password FROM admin_password").first
            pw_digest = result["password"]
            if password == password_confirm
                if BCrypt::Password.new(pw_digest) == admin_passkey
                    encrypted_password = BCrypt::Password.create(password)
                    db.execute("INSERT INTO user (username, email, age, account_age, games_played, games_reviewed, password, admin) VALUES (?,?,?,?,?,?,?,?)", username, email, age, date, 0, 0, encrypted_password, 1)
                    redirect('/')
                else
                    encrypted_password = BCrypt::Password.create(password)
                    db.execute("INSERT INTO user (username, email, age, account_age, games_played, games_reviewed, password, admin) VALUES (?,?,?,?,?,?,?,?)", username, email, age, date, 0, 0, encrypted_password, 0)
                    redirect('/')
                end
            else
                redirect('/error')
            end
        else
            redirect('/error')
        end
    end

    # Attempts to log into an account
    #
    # Redirects to home page if login successful
    # Redirects to error page if username entered password does not match existing password
    def account_login(db, username, password)
        result = db.execute("SELECT * FROM user WHERE username = ?", username).first
        pwdigest = result["password"]
        id = result["id"]
        if BCrypt::Password.new(pwdigest) == password
            session[:id] = id
            session[:username] = username
            redirect('/')
        else
            redirect('/error')
        end
    end

    # Adds a publisher to the database
    #
    def add_publisher_post(db, publisher_name, publisher_address, publisher_phone_number, active_since)
        db.execute("INSERT INTO publisher (name, adress, phone_number, active_since) VALUES (?,?,?,?)",publisher_name,publisher_address,publisher_phone_number,active_since)
    end

    # Adds a game to the database
    #
    # Redirect to error page if game already exists in the database
    def add_game_post(db, publisher, id, game_name, release_date, hrs_to_complete, path, genre1, genre2, genre3)
        publisher_id = db.execute("SELECT id FROM publisher WHERE name = ?",publisher).first["id"].to_i
        if db.execute("SELECT COUNT(1) FROM game WHERE name = ?", game_name).first["COUNT(1)"] < 1
            db.execute("INSERT INTO game (publisher_id, name,release_date, hrs_to_complete, image_file_name, publisher_name) VALUES (?,?,?,?,?,?)",publisher_id,game_name,release_date,hrs_to_complete,path, publisher)
        else 
            redirect('/error')
        end
        last_id = db.last_insert_row_id()
        genre1 = db.execute("SELECT id FROM genre WHERE name = ?",genre1).first["id"].to_i
        db.execute("INSERT INTO genre_relation (game_id, genre_id) VALUES (?,?)",last_id,genre1)
        if params[:genre2] != nil
            genre2 = db.execute("SELECT id FROM genre WHERE name = ?",genre2).first["id"].to_i
            db.execute("INSERT INTO genre_relation (game_id, genre_id) VALUES (?,?)",last_id,genre2)
        end
        if params[:genre3] != nil
            genre3 = db.execute("SELECT id FROM genre WHERE name = ?",genre3).first["id"].to_i
            db.execute("INSERT INTO genre_relation (game_id, genre_id) VALUES (?,?)",last_id,genre3)
        end
    end

    # Deletes a game from the database
    #
    def delete_game(db, game_name)
        game_id = db.execute("SELECT id FROM game WHERE name = ?", game_name)
        db.execute("DELETE FROM genre_relation WHERE game_id = ?", game_id)
        db.execute("DELETE FROM game WHERE name = ?", game_name)
    end

    # Deletes a publisher from the database
    #
    def delete_publisher(db, publisher_name)
        db.execute("DELETE FROM publisher WHERE name = ?", publisher_name)
    end
end