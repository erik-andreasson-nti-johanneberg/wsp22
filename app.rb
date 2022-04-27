require 'sinatra'
require 'slim'
require 'sqlite3'
require 'bcrypt'
require 'date'
require_relative './model.rb'

genres = ['Action', 'Shooter', 'Battle Royale', 'Stealth', 'Fighting', 'Survival', 'Rythm', 'Horror', 'Adventure', 'Puzzle', 'Action RPG', 'MMORPG', 'Roguelike', 'Tactical RPG', 'JRPG', 'Simulation', 'Strategy', 'MOBA', 'RTS', 'RTT', 'Tower Defense', 'TBS', 'TBT', 'Sports', 'Racing', 'MMO', 'Casual', 'Idle', 'Social Deduction']

enable :sessions

include Model

# Checks if input contains only numbers
#
def numbers_only_query(input)
    return input.scan(/\D/).empty?
end

# Checks if input contains an @ symbol
#
def email_query(input)
    return input.include?("@")
end

# Error page if input contained letters instead of numbers
#
get('/error_only_num') do
    slim(:error_only_num)
end

# Error page if input did not contain an @ symbol
#
get('/error_only_email') do
    slim(:error_only_email)
end

# Error page if user attempts login more than 3 times in a short interval
#
get('/error_login_attempts') do
    slim(:error_login_attempts)
end

# Error page if attempting to add a game or publisher to db if not admin
#
get('/must_be_admin') do
    slim(:must_be_admin)
end

# Homepage
#
# @see Model#home_page_games
get('/') do
    db = connect_to_db_with_hash()
    home_page_games = home_page_games(db)
    slim(:index, locals:{action_games:home_page_games[0], racing_games:home_page_games[1]})
end

# login page
#
get('/login') do
    slim(:"/login")
end

# create an account page
#
get('/users/new') do
    slim(:"users/new")
end

# Review page
#
# @param [String] :game_name, The name of the game
# @see Model#all_game_info
get('/review/new') do
    db = connect_to_db_with_hash()
    game_name = params[:game_name]
    game_info = all_game_info(db, game_name)
    slim(:"reviews/new", locals:{game_info:game_info})
end

# Add game page
#
# @see Model#add_game
get('/games/new') do
    db = connect_to_db_with_hash()
    add_game = add_game(db, session[:id])
    slim(:"games/new", locals:{names:add_game[0], genres:add_game[1], admin:add_game[2], games:add_game[3]})
end

# add publisher page
#
# @see Model#add_publisher
get('/publishers/new') do
    db = connect_to_db_with_hash()
    add_publisher = add_publisher(db, session[:id])
    slim(:"publishers/new", locals:{admin:add_publisher[0], publishers:add_publisher[1]})
end

# Game page when taken from button on home page
#
# @param [String] :game_name, The name of the game
# @see Model#game_page
get('/games') do
    db = connect_to_db_with_hash()
    game_name = params[:game_name]
    game_page = game_page(db, game_name)
    ratings = game_page[3]
    total_rating = 0.0
    if ratings[0] == nil
        ra = 0
    else
        ratings.each do |rating|
            rating = rating["rating"]
            rating = rating.to_f
            total_rating += rating
        end
        rating_average = total_rating/(ratings.length())
        rating_average = rating_average.round(0).to_s
        ra = rating_average
    end
    slim(:"games/index", locals:{publisher_name:game_page[0], game_info:game_page[1], reviews:game_page[2], ra:ra})
end

# Error page
#
get('/error') do
    slim(:error)
end

# Profile_page
#
# @see Model#profile_page 
get('/users') do
    db = connect_to_db_with_hash()
    profile_page = profile_page(db, session[:username])
    slim(:"users/index", locals:{profile_info:profile_page[0], reviews:profile_page[1], hrs_played:profile_page[2].to_s})
end


# show publishers
# 
# @see Model#show_publishers
get('/publishers') do
    db = connect_to_db_with_hash()
    show_publishers = show_publishers(db)
    slim(:"publishers/index", locals:{publisher_info:show_publishers})
end

#add review
#
# @param [String] :game_name, The name of the game
# @param [Integer] :finished_yes, 1 or 0 where 1 is finsihed the game and 0 is did not finish the game
# @param [Integer] :rating, Integer from 0 to 10 representing the rating the user gave the game
# @param [Integer] :hrs_played, Number of hours the user played the game
# @param [String] :review_text, The actual review text
# @see Model#add_review
post('/review') do
    db = connect_to_db_no_hash()
    game_name=params[:game_name]
    finished_q = params[:finished_yes]
    rating = params[:rating]
    if numbers_only_query(rating)
    else
        redirect('/error_only_num')
    end
    hrs_played = params[:hrs_played]
    if numbers_only_query(hrs_played)
    else
        redirect('/error_only_num')
    end
    review = params[:review_text]
    review_date = Date.today.to_s
    add_review(db, finished_q, game_name, rating, review, review_date, hrs_played, session[:username])
    redirect('/')
end

# Account creation
#
# @param [String] :username, Username of the new user
# @param [String] :password, Password of the new user
# @param [String] :password_confirm, Confirmation of the password of the new user
# @see Model#account_creation
post('/users') do
    db = connect_to_db_with_hash()
    username = params[:username]
    password = params[:password]
    password_confirm = params[:password_confirm]
    age = params[:age]
    if numbers_only_query(age)
    else
        redirect('/error_only_num')
    end
    email = params[:email]
    if email_query(email)
    else
        redirect('/error_only_email')
    end
    admin_passkey = params[:admin_passkey]
    date = Date.today.to_s
    error = account_creation(db, password, password_confirm, username, email, age, date, admin_passkey)
    if error
        redirect('/error')
    else
        redirect('/')
    end
end

# Account login
#
# @param [String] :username, Username of the user logging in
# @param [String] :password, Password of the user logging in
# @see Model#account_login
post('/login') do
    db = connect_to_db_with_hash()
    username = params[:username]
    password = params[:password]
    if session[:num_logins] == nil
        session[:num_logins] = 0
    end
    if session[:time_prev_attempt] == nil
        session[:time_prev_attempt] = Time.now.to_i
    end
    if Time.new.to_i - session[:time_prev_attempt] > 180
        session[:num_logins] = 0 
    end
    session[:time_prev_attempt] = Time.new.to_i

    if session[:num_logins] > 3
        redirect("/error_login_attempts")
    end
    error = account_login(db, username, password)
    if error[0]
        session[:num_logins] += 1
        session[:loginError] = 'Wrong username or password'
        redirect('/login')
    else
        session[:username] = username
        session[:id] = error[1]
        if error[2] == 1
            session[:admin] = 1
        end
        redirect('/')
    end
end

# Add publisher
#
# @param [String] :publisher_name, Name of the publisher to be added
# @param [String] :publisher_address, Adress of the publisher to be added
# @param [Integer] :publisher_phone_number, Phone number of the publisher to be added
# @param [String] :active_since, Date when the publisher to be added was founded
# @see Model#add_publisher_post
post('/publishers') do
    if session[:admin] == 1
        db = connect_to_db_with_hash()
        publisher_name = params[:publisher_name]
        publisher_address = params[:publisher_address]
        publisher_phone_number = params[:publisher_phone_number]
        if numbers_only_query(publisher_phone_number)
        else
            redirect('/error_only_num')
        end
        active_since = params[:active_since]
        add_publisher_post(db, publisher_name, publisher_address, publisher_phone_number, active_since, session[:username])
        redirect('/')
    else
        redirect('/must_be_admin')
    end
end

# Add game
# @param [String] :image, :filename, filename of the image to be uploaded
# @param [String] :image, :tempfile, File to be uploaded
# @param [String] :genre1, The first genre that the game is attributed to
# @param [String] :genre2, The second genre that the game is attributed to
# @param [String] :genre3, The third genre that the game is attrubuted to
# @param [String] :game_name, The name of the game to be added
# @param [String] :release_date, The date the game to be addded was released
# @param [Integer] :hrs_to_complete, Number of hours the game to be added usually takes to complete
# @param [String] :publisher, The publisher of the game to be added
# @see Model#add_game_post
post('/games') do
    if sesson[:admin] == 1
        db = connect_to_db_with_hash()
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
        genre1 = params[:genre1]
        genre2 = params[:genre2]
        genre3 = params[:genre3]
        game_name = params[:game_name]
        release_date = params[:release_date]
        hrs_to_complete = params[:hrs_to_complete].to_i
        if numbers_only_query(hrs_to_complete)
        else
            redirect('/error_only_num')
        end
        publisher = params[:publisher]
        error = add_game_post(db, publisher, id, game_name, release_date, hrs_to_complete, path, genre1, genre2, genre3, session[:username])
        if error
            redirect('/error')
        end
        redirect('/')
    else
        redirect('/must_be_admin')
    end
end

# post("/create_pw") do
#     db = SQLite3::Database.new("db/goodgames.db")
#     password = params[:password]
#     encrypted_password = BCrypt::Password.create(password)
#     db.execute("INSERT INTO admin_password (password) VALUES (?)", encrypted_password)
#     redirect("/")
# end

# Logout a user
#
post("/logout") do
    session.destroy
    redirect("/")
end

# Delete a game
#
# @see Model#delete_game
post('/games/delete') do
    if session[:admin] == 1
        game_name = params[:game]
        db = connect_to_db_no_hash()
        delete_game(db, game_name)
        redirect('/')
    else
        redirect('/must_be_admin')
    end
end

# Delete a publisher
#
# @see Model#delete_publisher
post('/publishers/delete') do
    if session[:admin] == 1
        publisher_name = params[:publisher]
        db = connect_to_db_no_hash()
        delete_publisher(db, publisher_name)
        redirect('/')
    else
        redirect('must_be_admin')
    end
end
