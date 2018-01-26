require 'sinatra'
require 'sinatra/reloader'
require 'tilt/erubis'
require 'redcarpet'

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

# render index or front page
get '/' do
  pattern = File.join(data_path, "*")
  @files = Dir.glob(pattern).map do |path|
    File.basename(path)
  end
  erb :index
end

# display page to create a new file
get '/new' do
  erb :new
end

# create a new file and save to Filesystem
post '/create' do
  filename = params[:filename]
  if filename.size == 0
    session[:message] = "A name is required."
    status 422
    erb :new
  else
    file_path = File.join(data_path, filename)

    File.write(file_path, "")

    session[:message] = "#{filename} was created."
    redirect '/'
  end
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
  file_path = File.join(data_path, params[:filename])

  @filename = params[:filename]
  @content = File.read(file_path)

  erb :edit
end

# edit and submit file changes
post '/:filename' do
  file_path = File.join(data_path, params[:filename])

  File.write(file_path, params[:textarea])

  session[:message] = "#{params[:filename]} has been updated."
  redirect '/'
end

# delete a file
post '/:filename/delete' do
  file_path = File.join(data_path, params[:filename])

  File.delete(file_path)
  
  session[:message] = "#{params[:filename]} was deleted."
  redirect '/'
end
