require 'sinatra'
require 'sinatra/reloader'
require 'tilt/erubis'
require 'redcarpet'
require 'yaml'
require 'bcrypt'

configure do
  enable :sessions
  set :session_secret, 'super secret'
end

root = File.expand_path("..", __FILE__)

def render_markdown(text)
  markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML)
  markdown.render(text)
end

def load_file_content(path)
  content = File.read(path)
  case File.extname(path)
  when ".txt"
    headers["Content-Type"] = "text/plain"
    content
  when ".md"
    render_markdown(content)
  end
end

def data_path
  if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/data", __FILE__)
  else
    File.expand_path("../data", __FILE__)
  end
end

def user_path
  if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/users.yaml", __FILE__)
  else
    File.expand_path("../users.yaml", __FILE__)
  end
end

def user_signed_in?
  session.key? :username
end

def require_signed_in_user
  unless user_signed_in?
    session[:message] = "You must be signed in to do that."
    redirect '/'
  end
end

def load_user_credentials
  credentials_path = if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/users.yaml", __FILE__)
  else
    File.expand_path("../users.yaml", __FILE__)
  end
  YAML.load_file(credentials_path)
end

def valid_credentials?(username, password)
  credentials = load_user_credentials

  if credentials.key? username
    bcrypt_password = BCrypt::Password.new(credentials[username])
    bcrypt_password == password
  else
    false
  end
end

# Validate that document names contain an extension that the application supports
def validate_file_ext?(filename)
  %w(.md .txt).include? File.extname(filename)
end

# render index or front page
get '/' do

  pattern = File.join(data_path, "*")
  @files = Dir.glob(pattern).map do |path|
    File.basename(path)
  end
  erb :index
end

get '/users/signin' do
  erb :signin
end

post '/users/signin' do
  username = params[:username]

  if valid_credentials?(username, params[:password])
    session[:username] = params[:username]
    session[:message] = "Welcome!"
    redirect '/'
  else
    session[:message] = "Invalid Credentials"
    status 442
    erb :signin
  end
end

post '/signout' do
  session.delete(:username)
  session[:message] = "You have been signed out."
  redirect '/'
end

get '/users/signup' do
  erb :signup
end

post '/users/signup' do
  username = params[:username]
  password = params[:password]

  new_user = "  #{username}: \"#{BCrypt::Password.create(password)}\""

  File.open(user_path, 'a') do |file|
    file.puts new_user
  end

  session[:message] = "New user #{username} created."
  redirect '/'
end

# display page to create a new file
get '/new' do
  require_signed_in_user

  erb :new
end

# create a new file and save to Filesystem
post '/create' do
  require_signed_in_user

  filename = params[:filename].strip

  if filename.size == 0
    session[:message] = "A name is required."
    status 422
    erb :new
  elsif !validate_file_ext?(filename)
    session[:message] = "Unsupported extension"
    status 422
    erb :new
  else
    file_path = File.join(data_path, filename)

    File.write(file_path, "")

    session[:message] = "#{filename} was created."
    redirect '/'
  end
end

# Creating new document based on an old one (duplicates)
post '/:filename/duplicate' do
  require_signed_in_user

  filename = params[:filename]

  file, ext = filename.split(".")

  session[filename] ||= []
  session[filename] <<  file + "#{session[filename].size}" + ".#{ext}"
  file_path = File.join(data_path, session[filename].last)

  org_file_content = File.read(File.join(data_path, filename))

  File.write(file_path, "#{org_file_content}")

  session[:message] = "#{filename} duplicate created."

  redirect '/'
end

# display file contents
get '/:filename' do
  file_path = File.join(data_path, params[:filename])

  if File.exist? file_path
    load_file_content(file_path)
  else
    session[:message] = "#{params[:filename]} does not exist."
    redirect '/'
  end
end

# display page to edit a file
get '/:filename/edit' do
  require_signed_in_user

  file_path = File.join(data_path, params[:filename])

  @filename = params[:filename]
  @content = File.read(file_path)

  erb :edit
end

# edit and submit file changes
post '/:filename' do
  require_signed_in_user

  file_path = File.join(data_path, params[:filename])

  File.write(file_path, params[:textarea])

  session[:message] = "#{params[:filename]} has been updated."
  redirect '/'
end

# delete a file
post '/:filename/delete' do
  require_signed_in_user

  file_path = File.join(data_path, params[:filename])

  File.delete(file_path)

  session[:message] = "#{params[:filename]} was deleted."
  redirect '/'
end
