class GrouplensParser
  
  # This parses the files downloaded at MovieLens ( http://www.grouplens.org/node/73 )
  # This is for the 10 million ratings and 100,000 tags for 10681 movies by 71567 users dataset
  
  attr_accessor :base_dir
  
  def initialize(base_dir)
    @base_dir = base_dir
  end
  
  def parse
    #1::Toy Story (1995)::Adventure|Animation|Children|Comedy|Fantasy
    movies = {}
    IO.readlines(File.join(@base_dir, "movies.dat")).each do |line|
      id, title, genres = line.split("::")
      movies[id] = title
    end
    
    users = {}
    #1::122::5::838985046
    IO.readlines(File.join(@base_dir, "ratings.dat")).each do |line|
      id, movie_id, rating, timestamp = line.split("::")
      users[id] = Hash.new unless users[id]
      users[id][movie_id] = rating
    end
    users
  end
end