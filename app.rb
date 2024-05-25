require "sinatra"
#require "sinatra/reloader" if development?
require "http"
require "sinatra/cookies"
require "open-uri"
require "nokogiri"

require "matrix"

get("/") do
  erb(:chemical_equation_form)
end

post("/process_chemical_equation") do
  # Get user inputs
  @reactants = params.fetch("reactants") #get reactants list
  @products = params.fetch("products") #get products list

  @product_amount = params.fetch("product_amount") #get product amount

  # Parse each term and translate to chemical formulas
  #  perform operation separately for reactants and products
  dict_reactants_formulas = fetch_chemical_formulas(@reactants.split(','))
  dict_products_formulas = fetch_chemical_formulas(@products.split(',')) 

  #1. CHEMICAL FORMULA - dictionary keys
  # Join formulas with '+' and create the chemical equation
  @chemical_equation = dict_reactants_formulas.values.map(&:first).join(" + ") + " → " + dict_products_formulas.values.map(&:first).join(" + ") #output: pass chemical equation to chemical_equation_result web-page

  #2. MOLECULAR WEIGHTS - dictionary values
  @mw = dict_reactants_formulas.merge(dict_products_formulas)

  #3. CALCULATE NUMBER OF MOLES OF DESIRED PRODUCT
  product_parts = @product_amount.split(',')
  product_name = product_parts[0].strip
  product_amount = product_parts[1].strip

  result = product_amount.to_f / dict_products_formulas[product_name][1].to_f

  # Format the result in scientific notation
  formatted_result = sprintf("%.3e", result)

  # If the exponent is `e+00`, write it as a decimal
  if formatted_result.include?('e+00')
    # Truncate to 3 significant figures
    @moles_of_product = sprintf("%.3g", result)
  else
    @moles_of_product = formatted_result
  end

  erb(:chemical_equation_result)
end



def fetch_chemical_formulas(chemicals)
  """Convert a list of chemical names into a list of chemical formulas using NIST webbook API.
     Input:
      - a chemical name
    
     Output:
      - a dictionary with chemical name as the key and an array of chemical formula and molecular weight as the values
  """

  #use dictionary
  dict_chemical_formulas={}

  chemicals.each do |chemical|
    url = "https://webbook.nist.gov/cgi/cbook.cgi?Name=#{chemical}&Units=SI"
    html = URI.open(url).read

    # Chemical formula
    formula_lines, mw_lines = extract_formula_lines(html)

    #dict_chemical_formulas[formula_lines]=mw_lines
    dict_chemical_formulas[chemical.strip] = [formula_lines, mw_lines]
  end

  return dict_chemical_formulas
end


# Function to extract lines containing "Formula:" from HTML
def extract_formula_lines(html)
  """Extract chemical formula from NIST website. Store the search result in an array to account for multiple instances.
  """

  doc = Nokogiri::HTML(html)
  formula_lines = [] #store chemical formulas
  mw_lines =[] #store molecular weights

  # Use Nokogiri's CSS selector to efficiently find the formula
  doc.css('body').text.each_line do |line|

    if line.include?("Formula:") # Get chemical formula
      formula_lines << extract_value(line.strip) # Collect all matching answers

    elsif line.include?("Molecular weight:") # Get molar mass
      mw_lines << extract_molecular_weight(line.strip)
    end

    # If both lists have at least one element, exit the loop
    if formula_lines.length == 1 && mw_lines.length == 1
      break
    end

  end

  return formula_lines[0], mw_lines[0] # Take the last ones
end

def extract_molecular_weight(string)
  """Extract molecular weight
  """

  match = string.match(/Molecular weight: (\d+\.\d+)/)
  match[1].to_f if match
end


def extract_value(string)
  """Extract a value from, e.g., Formula: C6H6 according to the string pattern. 
     Also, convert the numbers proceeding the letters into
  """

  # Split the string by space and retrieve the second part
  parts = string.split(" ")
  parts[1] if parts.length >= 2

  return convert_to_subscripts(parts[1])
end

def convert_to_subscripts(input)
  """Convert numbers proceeding letters into subscripts
  """

  # Define a hash map for converting numbers to their subscript equivalents
  subscripts = {
    '0' => '₀', '1' => '₁', '2' => '₂', '3' => '₃', '4' => '₄',
    '5' => '₅', '6' => '₆', '7' => '₇', '8' => '₈', '9' => '₉'
  }

  # Use a regular expression to find numbers following letters
  input.gsub(/(\D)(\d+)/) do |match|
    # Match[1] is the non-digit character, match[2] is the number sequence
    letter = $1
    number = $2.chars.map { |digit| subscripts[digit] }.join
    "#{letter}#{number}"
  end
end
