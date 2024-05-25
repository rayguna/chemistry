require "sinatra"
require "sinatra/reloader"

require "http"
require "sinatra/cookies"

get("/") do
  
  erb(:chemical_equation_form)

end

post("/process_chemical_equation") do #linked from chemical equation form action

  #Get user inputs
  @reactants = params.fetch("reactants")
  @products = params.fetch("products")

  #parse each term and translate to chemical formulas
  list_reactants = @reactants.split(',')
  list_products = @products.split(',')

  #iterate through each reactants
  #list_reactants.each do |reactant|
    #url = "https://webbook.nist.gov/cgi/cbook.cgi?Name=#{reactant}&Units=SI"
  #end

  #need to do the same for each reactants and products 
  url = "https://webbook.nist.gov/cgi/cbook.cgi?Name=" + list_reactants[0] +"&Units=SI"

  # Fetch the HTML content of the page
  html = URI.open(url)
  
  #web scrape chemical formula
  formula_lines = extract_formula_lines(html)

  #pass chemical formula
  @parsed_response = formula_lines


  erb(:chemical_equation_result)

end

# Function to extract lines containing "Formula:" from HTML
def extract_formula_lines(html)
  """Get the chemical formula by going through each line in the html output.
  """

  doc = Nokogiri::HTML(html)
  
  # Iterate through each line of text in the HTML
  doc.text.each_line do |line|
    # Check if the line contains "Formula:"
    if line.include?("Formula:")
      #return line.strip
      return extract_formula_value(line)
    end
  end

end


def extract_formula_value(string)
  
  # Split the string by space and retrieve the second part
  parts = string.split(" ")
  formula_value = parts[1] if parts.length >= 2
  
  # Return the extracted formula value
  return formula_value
end
