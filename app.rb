require 'sinatra'
require 'slim'
require 'sqlite3'
require 'bcrypt'
require 'date'

genres = ['Action', 'Shooter', 'Battle Royale', 'Stealth', 'Fighting', 'Survival', 'Rythm', 'Horror', 'Adventure', 'Puzzle', 'Action RPG', 'MMORPG', 'Roguelike', 'Tactical RPG', 'JRPG', 'Simulation', 'Strategy', 'MOBA', 'RTS', 'RTT', 'Tower Defense', 'TBS', 'TBT', 'Sports', 'Racing', 'MMO', 'Casual', 'Idle', 'Social Deduction']

enable :sessions

#Homepage
get('/') do
    db = SQLite3::Database.new("db/goodgames.db")
    db.results_as_hash = true
    action_games = db.execute("SELECT * FROM game WHERE id IN (SELECT game_id FROM genre_relation WHERE genre_id = 1)")
    racing_games = db.execute("SELECT * FROM game WHERE id IN (SELECT game_id FROM genre_relation WHERE genre_id = 24)")
    p action_games
    p racing_games
    slim(:home, locals:{action_games:action_games, racing_games:racing_games})
end

#login page
get('/login') do
    slim(:login)
end

#create an account page
get('/create_account') do
    slim(:create_account)
end

#Games page
get('/popular') do
    slim(:games)
end

#Review page
get('/review') do
    db = SQLite3::Database.new("db/goodgames.db")
    db.results_as_hash = true
    game_name = params[:game_name]
    p game_name
    game_info = db.execute("SELECT * FROM game WHERE name = ?",game_name).first
    slim(:review, locals:{game_info:game_info})
end

#add game page
get('/addgame') do
    db = SQLite3::Database.new("db/goodgames.db")
    db.results_as_hash = true
    publisher_names = db.execute("SELECT name FROM publisher")
    genres = db.execute("SELECT name FROM genre")
    slim(:addgame, locals:{names:publisher_names, genres:genres})
end

#add publisher page
get('/addpublisher') do
    slim(:addpublisher)
end

#game page when taken from button
get('/go_to_game_page') do
    db = SQLite3::Database.new("db/goodgames.db")
    db.results_as_hash = true
    game_name = params[:game_name]
    game_id = db.execute("SELECT id FROM game WHERE name=?", game_name).first
    p game_id
    game_id = game_id["id"]
    p game_id
    publisher_name = db.execute("SELECT name FROM publisher WHERE id IN (SELECT publisher_id FROM game WHERE name = ?)",game_name).first
    game_info = db.execute("SELECT * FROM game WHERE name = ?",game_name).first
    reviews = db.execute("SELECT * FROM review WHERE game_id = ?", game_id)
    slim(:game_page, locals:{publisher_name:publisher_name, game_info:game_info, reviews:reviews})
end

#error page
get('/error') do
    slim(:error)
end

#add image test
get('/addimage') do
    slim(:add_image_test)
end

#profile_page 
get('/profile') do
    slim(:profile)
end

#add review
post('/finished_r') do
    db = SQLite3::Database.new("db/goodgames.db")
    game_name=params[:game_name]
    if params[:finished_yes]
        finished = 1
    else
        finished = 0
    end
    rating = params[:rating]
    hrs_played = params[:hrs_played]
    review = params[:review_text]
    review_date = Date.today.to_s
    user_id = db.execute("SELECT id FROM user WHERE username = ?", session[:username])
    game_id = db.execute("SELECT id FROM game WHERE name = ?", game_name)
    db.execute("INSERT INTO review (rating, user_id, comments, review_date, game_id, finished) VALUES (?,?,?,?,?,?)",rating, user_id, review, review_date, game_id, finished)
    redirect('/')
end


#add_image_test
post('/adding_image_test') do
    if params[:image] && params[:image][:filename]
        filename = params[:image][:filename]
        file = params[:image][:tempfile]
        path = "./public/uploads/#{filename}"
        File.open(path, 'w') do |f|
            f.write(file.read)
        end
    end
end

#account creation
post('/account_creation') do
    db = SQLite3::Database.new("db/goodgames.db")
    db.results_as_hash = true
    username = params[:username]
    password = params[:password]
    password_confirm = params[:password_confirm]
    age = params[:age]
    email = params[:email]
    admin_passkey = params[:admin_passkey]
    date = Date.today.to_s
    p date 

    if password == password_confirm
        encrypted_password = BCrypt::Password.create(password)
        db.execute("INSERT INTO user (username, email, age, account_age, games_played, games_reviewed, password) VALUES (?,?,?,?,?,?,?)", username, email, age, date, 0, 0, encrypted_password)
        redirect('/')
    else
      redirect('/error')
    end
end

#account login
post('/login') do
    db = SQLite3::Database.new("db/goodgames.db")
    db.results_as_hash = true
    username = params[:username]
    password = params[:password]
    result = db.execute("SELECT * FROM user WHERE username = ?", username).first
    pwdigest = result["password"]
    id = result["id"]
    if BCrypt::Password.new(pwdigest) == password
        session[:id] = id
        session[:username] = username
        p session[:username]
        redirect('/')
    else
        redirect('/error')
    end
end

post('/addingpublisher') do
    db = SQLite3::Database.new("db/goodgames.db")
    db.results_as_hash = true
    publisher_name = params[:publisher_name]
    publisher_address = params[:publisher_address]
    publisher_phone_number = params[:publisher_phone_number]
    active_since = params[:active_since]
    db.execute("INSERT INTO publisher (name, adress, phone_number, active_since) VALUES (?,?,?,?)",publisher_name,publisher_address,publisher_phone_number,active_since)
    redirect('/')
end

post('/addinggame') do
    db = SQLite3::Database.new("db/goodgames.db")
    db.results_as_hash = true
    #image form
    # Check if user uploaded a file
    filename = params[:image][:filename]
    file = params[:image][:tempfile]
    path = "../uploads/#{filename}"
    path_file_write = "./public/uploads/#{filename}"
    File.open(path_file_write, 'w') do |f|
        f.write(file.read)
    end
    #params
    game_name = params[:game_name]
    release_date = params[:release_date]
    hrs_to_complete = params[:hrs_to_complete].to_i
    publisher = params[:publisher]
    publisher_id = db.execute("SELECT id FROM publisher WHERE name = ?",publisher).first["id"].to_i
    #game db insertion
    if db.execute("SELECT COUNT(1) FROM game WHERE name = ?", game_name).first["COUNT(1)"] < 1
        db.execute("INSERT INTO game (publisher_id, name,release_date, hrs_to_complete, image_file_name) VALUES (?,?,?,?,?)",publisher_id,game_name,release_date,hrs_to_complete,path)
    else 
        redirect('/error')
    end
    last_id = db.last_insert_row_id()
    p last_id
    #genre relation insertion
    genre1 = db.execute("SELECT id FROM genre WHERE name = ?",params[:genre1]).first["id"].to_i
    db.execute("INSERT INTO genre_relation (game_id, genre_id) VALUES (?,?)",last_id,genre1)
    if params[:genre2] != nil
        genre2 = db.execute("SELECT id FROM genre WHERE name = ?",params[:genre2]).first["id"].to_i
        db.execute("INSERT INTO genre_relation (game_id, genre_id) VALUES (?,?)",last_id,genre2)
    end
    if params[:genre3] != nil
        genre3 = db.execute("SELECT id FROM genre WHERE name = ?",params[:genre3]).first["id"].to_i
        db.execute("INSERT INTO genre_relation (game_id, genre_id) VALUES (?,?)",last_id,genre3)
    end
    redirect('/')
end
