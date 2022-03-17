require 'sinatra'
require 'slim'
require 'sqlite3'
require 'bcrypt'
require 'date'
require_relative './model.rb'

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
    slim(:index, locals:{action_games:action_games, racing_games:racing_games})
end

#login page
get('/users/login') do
    slim(:"users/login")
end

#create an account page
get('/users/new') do
    slim(:"users/new")
end

# #Games page
# get('/popular') do
#     slim(:games)
# end

#Review page
get('/games/review') do
    db = SQLite3::Database.new("db/goodgames.db")
    db.results_as_hash = true
    game_name = params[:game_name]
    p game_name
    game_info = db.execute("SELECT * FROM game WHERE name = ?",game_name).first
    slim(:"games/review", locals:{game_info:game_info})
end

#add game page
get('/games/new') do
    db = SQLite3::Database.new("db/goodgames.db")
    db.results_as_hash = true
    publisher_names = db.execute("SELECT name FROM publisher")
    genres = db.execute("SELECT name FROM genre")
    admin = db.execute("SELECT admin FROM user WHERE id = ?", session[:id]).first
    games = db.execute("SELECT name FROM game")
    slim(:"games/new", locals:{names:publisher_names, genres:genres, admin:admin, games:games})
end

#add publisher page
get('/publishers/new') do
    db = SQLite3::Database.new("db/goodgames.db")
    db.results_as_hash = true
    admin = db.execute("SELECT admin FROM user WHERE id = ?", session[:id]).first
    publishers = db.execute("SELECT name FROM publisher")
    slim(:"publishers/new", locals:{admin:admin, publishers:publishers})
end

#game page when taken from button
get('/games/index') do
    db = SQLite3::Database.new("db/goodgames.db")
    db.results_as_hash = true
    game_name = params[:game_name]
    game_id = db.execute("SELECT id FROM game WHERE name=?", game_name).first
    game_id = game_id["id"]
    publisher_name = db.execute("SELECT name FROM publisher WHERE id IN (SELECT publisher_id FROM game WHERE name = ?)",game_name).first
    game_info = db.execute("SELECT * FROM game WHERE name = ?",game_name).first
    reviews = db.execute("SELECT * FROM review WHERE game_id = ?", game_id)
    total_rating = 0.0
    ratings = db.execute("SELECT rating FROM review")
    p ratings
    ratings.each do |rating|
        p rating
        rating = rating["rating"]
        rating = rating.to_f
        total_rating += rating
    end
    p ratings.length()
    rating_average = total_rating/(ratings.length())
    rating_average = rating_average.round(0).to_s
    p rating_average
    ra = rating_average
    p ra
    slim(:"games/index", locals:{publisher_name:publisher_name, game_info:game_info, reviews:reviews, ra:ra})
end

#error page
get('/error') do
    slim(:error)
end

# #add image test
# get('/addimage') do
#     slim(:add_image_test)
# end

#profile_page 
get('/users/index') do
    db = SQLite3::Database.new("db/goodgames.db")
    db.results_as_hash = true
    profile_info = db.execute("SELECT * FROM user WHERE username = ?", session[:username]).first
    reviews = db.execute("SELECT * FROM review WHERE username = ?", session[:username])
    slim(:"users/index", locals:{profile_info:profile_info, reviews:reviews})
end

# get('/create_pw') do
#     slim(:create_admin_pw)
# end

#add review
post('/games/review') do
    db = SQLite3::Database.new("db/goodgames.db")
    db.execute("UPDATE user SET games_reviewed = games_reviewed + 1 WHERE username = ?", session[:username])
    game_name=params[:game_name]
    if params[:finished_yes]
        finished = 1
        db.execute("UPDATE user SET games_played = games_played + 1 WHERE username = ?", session[:username])
    else
        finished = 0
    end
    rating = params[:rating]
    hrs_played = params[:hrs_played]
    review = params[:review_text]
    review_date = Date.today.to_s
    game_id = db.execute("SELECT id FROM game WHERE name = ?", game_name)
    db.execute("INSERT INTO review (rating, username, comments, review_date, game_id, finished) VALUES (?,?,?,?,?,?)",rating, session[:username], review, review_date, game_id, finished)
    redirect('/')
end


# #add_image_test
# post('/adding_image_test') do
#     if params[:image] && params[:image][:filename]
#         filename = params[:image][:filename]
#         file = params[:image][:tempfile]
#         path = "./public/uploads/#{filename}"
#         File.open(path, 'w') do |f|
#             f.write(file.read)
#         end
#     end
# end

#account creation
post('/users/new') do
    db = SQLite3::Database.new("db/goodgames.db")
    db.results_as_hash = true
    username = params[:username]
    password = params[:password]
    password_confirm = params[:password_confirm]
    age = params[:age]
    email = params[:email]
    admin_passkey = params[:admin_passkey]
    date = Date.today.to_s
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
end

#account login
post('/users/login') do
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

post('/publishers/new') do
    db = SQLite3::Database.new("db/goodgames.db")
    db.results_as_hash = true
    publisher_name = params[:publisher_name]
    publisher_address = params[:publisher_address]
    publisher_phone_number = params[:publisher_phone_number]
    active_since = params[:active_since]
    db.execute("INSERT INTO publisher (name, adress, phone_number, active_since) VALUES (?,?,?,?)",publisher_name,publisher_address,publisher_phone_number,active_since)
    redirect('/')
end

post('/games') do
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

# post("/create_pw") do
#     db = SQLite3::Database.new("db/goodgames.db")
#     password = params[:password]
#     encrypted_password = BCrypt::Password.create(password)
#     db.execute("INSERT INTO admin_password (password) VALUES (?)", encrypted_password)
#     redirect("/")
# end

post("/users/logout") do
    session.destroy
    redirect("/")
end

post('/games/delete') do
    db = SQLite3::Database.new("db/goodgames.db")
    db.execute("DELETE FROM game WHERE name = ?", params[:game])
    redirect('/')
end

post('/publishers/delete') do
    db = SQLite3::Database.new("db/goodgames.db")
    db.execute("DELETE FROM publisher WHERE name = ?", params[:publisher])
    redirect('/')
end
