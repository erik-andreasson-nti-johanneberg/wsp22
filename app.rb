require 'sinatra'
require 'slim'
require 'sqlite3'
require 'bcrypt'
require 'date'
require_relative './model.rb'

genres = ['Action', 'Shooter', 'Battle Royale', 'Stealth', 'Fighting', 'Survival', 'Rythm', 'Horror', 'Adventure', 'Puzzle', 'Action RPG', 'MMORPG', 'Roguelike', 'Tactical RPG', 'JRPG', 'Simulation', 'Strategy', 'MOBA', 'RTS', 'RTT', 'Tower Defense', 'TBS', 'TBT', 'Sports', 'Racing', 'MMO', 'Casual', 'Idle', 'Social Deduction']

enable :sessions

def numbers_only_query(input)
    return input.scan(/\D/).empty?
end

def email_query(input)
    return input.include?("@")
end

get('/error_only_num') do
    slim(:error_only_num)
end

get('/error_only_email') do
    slim(:error_only_email)
end

#Homepage
get('/') do
    db = connect_to_db_with_hash()
    home_page_games = home_page_games(db)
    slim(:index, locals:{action_games:home_page_games[0], racing_games:home_page_games[1]})
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
    db = connect_to_db_with_hash()
    game_name = params[:game_name]
    game_info = all_game_info(db, game_name)
    p game_info
    slim(:"games/review", locals:{game_info:game_info})
end

#add game page
get('/games/new') do
    db = connect_to_db_with_hash()
    add_game = add_game(db)
    slim(:"games/new", locals:{names:add_game[0], genres:add_game[1], admin:add_game[2], games:add_game[3]})
end

#add publisher page
get('/publishers/new') do
    db = connect_to_db_with_hash()
    add_publisher = add_publisher(db)
    slim(:"publishers/new", locals:{admin:add_publisher[0], publishers:add_publisher[1]})
end

#game page when taken from button
get('/games/index') do
    db = connect_to_db_with_hash()
    game_name = params[:game_name]
    game_page = game_page(db, game_name)
    p game_page
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
    db = connect_to_db_with_hash()
    profile_page = profile_page(db)
    slim(:"users/index", locals:{profile_info:profile_page[0], reviews:profile_page[1], hrs_played:profile_page[2].to_s})
end

# get('/create_pw') do
#     slim(:create_admin_pw)
# end

# show publishers
get('/publishers/index') do
    db = connect_to_db_with_hash()
    show_publishers = show_publishers(db)
    slim(:"publishers/index", locals:{publisher_info:show_publishers})
end

#add review
post('/games/review') do
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
    add_review(db, finished_q, game_name, rating, review, review_date, hrs_played)
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
    account_creation(db, password, password_confirm, username, email, age, date, admin_passkey)
end

#account login
post('/users/login') do
    db = connect_to_db_with_hash()
    username = params[:username]
    password = params[:password]
    account_login(db, username, password)
end

# add publisher post
post('/publishers/new') do
    db = connect_to_db_with_hash()
    publisher_name = params[:publisher_name]
    publisher_address = params[:publisher_address]
    publisher_phone_number = params[:publisher_phone_number]
    if numbers_only_query(publisher_phone_number)
    else
        redirect('/error_only_num')
    end
    active_since = params[:active_since]
    add_publisher_post(db, publisher_name, publisher_address, publisher_phone_number, active_since)
    redirect('/')
end

# add game post
post('/games/new') do
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
    add_game_post(db, publisher, id, game_name, release_date, hrs_to_complete, path, genre1, genre2, genre3)
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
    game_name = params[:game]
    db = connect_to_db_no_hash()
    delete_game(db, game_name)
    redirect('/')
end

post('/publishers/delete') do
    publisher_name = params[:publisher]
    db = connect_to_db_no_hash()
    delete_publisher(db, publisher_name)
    redirect('/')
end
