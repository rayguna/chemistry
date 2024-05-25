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

  #url = "https://webbook.nist.gov/cgi/cbook.cgi?Name=" + "water" + "&Units=SI"
  
  #@raw_response = HTTP.post(url).to_s

  #@parsed_response = JSON.parse(@raw_response)

  #@loc_hash = @parsed_response.dig("results", 0, "geometry", "location")

  #list_reactants.each do |reactant|
  #  @outp = https://webbook.nist.gov/cgi/cbook.cgi?Name=reactant&Units=SI
  #end

  erb(:chemical_equation_result)

end
