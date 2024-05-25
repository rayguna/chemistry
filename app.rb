require "sinatra"
require "http"
require "sinatra/cookies"
require "open-uri"
require "nokogiri"

require "matrix"

get("/") do
  erb(:chemical_equation_form)
end

post("/process_chemical_equation") do
  @reactants = params.fetch("reactants")
  @products = params.fetch("products")
  @target_product = params.fetch("product_amount")

  dict_reactants_formulas = fetch_chemical_formulas(@reactants.split(','))
  dict_products_formulas = fetch_chemical_formulas(@products.split(','))

  @chemical_equation = format_chemical_equation(dict_reactants_formulas, dict_products_formulas)

  @dict_all_compounds = dict_reactants_formulas.merge(dict_products_formulas)

  product_parts = @target_product.split(',')
  @product_name = product_parts[0].strip
  @product_amount = product_parts[1].strip

  # Calculate the number of moles of the desired product and add to the dictionary
  result = @product_amount.to_f / dict_products_formulas[@product_name][2].to_f

  @moles_of_product = format_result(result)
  @dict_all_compounds[@product_name][3] = @moles_of_product

  #add mass info to dictionary of product compound as well
  @dict_all_compounds[@product_name][4] = sprintf("%.3g", @product_amount)

  moles_of_product_N  = @moles_of_product.to_f / dict_products_formulas[@product_name][0].to_f #normalized moles of product

  # Calculate number of moles of the rest of the substances
  text = ""

  @dict_all_compounds.each do |compound, values| #extract keys and values
    next if compound == @product_name # Skip the desired product
    
    moles = moles_of_product_N * values[0] #substance's coefficient times normalized product moles.

    #add to the respective dictionary
    @dict_all_compounds[compound][3] = moles

    #calculate the masses in grams
    mass = sprintf("%.3g", moles * values[2])
    @dict_all_compounds[compound][4] = mass

    text += "• " + compound + ": " + mass + " g <br>"
  end

  @report_result = text

  
  erb(:chemical_equation_result)
end


def format_chemical_equation(dict_reactants_formulas, dict_products_formulas)
  reactants = dict_reactants_formulas.values.map { |value| value[0].to_s + " " + value[1].to_s }.join(" + ")
  products = dict_products_formulas.values.map { |value| value[0].to_s + " " + value[1].to_s }.join(" + ")
  "#{reactants} → #{products}"
end

def format_result(result)
  formatted_result = sprintf("%.3e", result)
  formatted_result.include?('e+00') ? sprintf("%.3g", result) : formatted_result
end


def fetch_chemical_formulas(chemicals)
  dict_chemical_formulas = Hash.new { |hash, key| hash[key] = [1, nil, nil] }

  unique_chemicals = chemicals.uniq
  unique_chemicals.each do |chemical|
    coefficient = 1
    if chemical.include?("*")
      coefficient, chemical = chemical.split("*")
    end

    url = "https://webbook.nist.gov/cgi/cbook.cgi?Name=#{chemical.strip}&Units=SI"
    html = URI.open(url).read

    formula_lines, mw_lines = extract_formula_lines(html)

    dict_chemical_formulas[chemical.strip][0] = coefficient.to_i
    dict_chemical_formulas[chemical.strip][1] = formula_lines
    dict_chemical_formulas[chemical.strip][2] = mw_lines
  end

  dict_chemical_formulas
end


def extract_formula_lines(html)
  doc = Nokogiri::HTML(html)
  formula_lines = []
  mw_lines = []

  doc.css('body').text.each_line do |line|
    if line.include?("Formula:")
      formula_lines << extract_value(line.strip)
    elsif line.include?("Molecular weight:")
      mw_lines << extract_molecular_weight(line.strip)
    end

    break if formula_lines.length == 1 && mw_lines.length == 1
  end

  [formula_lines[0], mw_lines[0]]
end

def extract_molecular_weight(string)
  match = string.match(/Molecular weight: (\d+\.\d+)/)
  match ? match[1].to_f : nil
end

def extract_value(string)
  parts = string.split(" ")
  convert_to_subscripts(parts[1]) if parts.length >= 2
end

def convert_to_subscripts(input)
  subscripts = {
    '0' => '₀', '1' => '₁', '2' => '₂', '3' => '₃', '4' => '₄',
    '5' => '₅', '6' => '₆', '7' => '₇', '8' => '₈', '9' => '₉'
  }

  input.gsub(/(\D)(\d+)/) do |match|
    letter = $1
    number = $2.chars.map { |digit| subscripts[digit] }.join
    "#{letter}#{number}"
  end
end
