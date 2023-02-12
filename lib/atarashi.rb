require 'mysql2'
require 'open-uri'
require 'nokogiri'

class NewsAggregator
  attr_reader :sources

  def initialize(sources)
    @sources = sources
    @client = Mysql2::Client.new(
      host: "localhost",
      username: "root",
      password: "password",
      database: "news_aggregator"
    )
    create_articles_table
  end

  def create_articles_table
    @client.query("
      CREATE TABLE IF NOT EXISTS articles (
        id INT AUTO_INCREMENT PRIMARY KEY,
        title VARCHAR(255),
        description TEXT
      )
    ")
  end

  def fetch_articles(article_type = nil)
    articles = []
    sources.each do |source|
      doc = Nokogiri::HTML(open(source))
      doc.css("article").each do |article|
        next if article_type && article.css("h3").text.downcase != article_type.downcase
        title = article.css("h2").text
        description = article.css("p").text
        articles << { title: title, description: description }
      end
    end
    articles
  end

  def save_articles_to_db(article_type = nil)
    articles = fetch_articles(article_type)
    return if articles.empty?

    articles.each do |article|
      @client.query("
        INSERT INTO articles (title, description)
        VALUES ('#{article[:title]}', '#{article[:description]}')
      ")
    end
    puts "Articles saved to database."
  end

  def retrieve_articles_from_db
    articles = []
    result = @client.query("SELECT * FROM articles")
    result.each do |row|
      articles << { id: row["id"], title: row["title"], description: row["description"] }
    end
    articles
  end

  def display_articles_from_db
    articles = retrieve_articles_from_db
    if articles.empty?
      puts "No articles found in database."
    else
      puts "Latest news articles:"
      articles.each do |article|
        puts "Title: #{article[:title]}"
        puts "Description: #{article[:description]}"
        puts "---"
      end
    end
  end
end

# example usage
news_sources = [
  "https://www.bbc.com/news",
  "https://www.aljazeera.com/news",
  "https://www.reuters.com/news/world"
]

aggregator = NewsAggregator.new(news_sources)
aggregator.save_articles_to_db("World")
aggregator.display_articles_from_db
