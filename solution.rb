# http://en.wikipedia.org/wiki/Zebra_Puzzle#Step_1
require 'json' 

@constraints = [
  "nationality/0 == color/2",
  "nationality/1 == pet/1",
  "drink/0 == color/1",
  "nationality/2 == drink/3",
  "color/0 +1 color/1",
  "smoke/0 == pet/2",
  "smoke/1 == color/4",
  "drink/1 == number/3",
  "nationality/3 == number/1",
  "smoke/2 next pet/3",
  "smoke/1 next pet/4",
  "smoke/4 == drink/2",
  "nationality/4 == smoke/3",
  "pet/0?",
  "nationality/3 next color/3"
]

@keys = [
  "number","color","nationality","drink","smoke","pet"
]

@constants = {
  "nationality" => ["english","spanish","ukraine","norway","japan"],
  "color"       => ["ivory","green","red","blue","yellow"],
  "smoke"       => ["oldGold","kools","chester","parliament","lucky"],
  "pet"         => ["zebra","dog","snail","fox","horse"],
  "drink"       => ["coffee","milk","oj","tea","water"],
  "number"      => [0,1,2,3,4]
}

@numHouses = 5

def initDataStructure()
  output = []
  @numHouses.times do |i|
    output[i] = {}
    @keys.each do |key|
      output[i][key] = {}
      output[i][key]["good"] = nil
      output[i][key]["bad"] = []
    end
    output[i]["number"]["good"] = i
    @numHouses.times do |j|
      output[i]["number"]["bad"] << j if i != j
    end
  end
  return output
end

# Add key in correct place and add to bad in all others
def foundCertain(houseNum,key,value,ds)
  warn "num: #{houseNum}, key: #{key}, value: #{value}"
  ds[houseNum][key]["good"] = value
  ds.each do |house|
    if house["number"]["good"] != houseNum && !house[key]["bad"].include?(value)
      house[key]["bad"] << value
    end
  end
end

def getHouseNum(house)
  return house["number"]["good"]
end

def applyConstraint(constraint, ds)
  if (/==/.match(constraint))
    warn "Constriant: #{constraint}"
    # For the == case, check if either of the cases is satisfied in any house and apply the other
    captured = /([^\/]*)\/([^\s]*) == ([^\/]*)\/([^\s]*)/.match(constraint)
    key1 = captured[1]
    value1 = captured[2].to_i
    key2 = captured[3]
    value2 = captured[4].to_i
    ds.each do |house|
      if house[key2]["good"] == value2
        foundCertain(getHouseNum(house),key1,value1,ds)
      elsif house[key1]["good"] == value1
        foundCertain(getHouseNum(house),key2,value2,ds)
      end      
    end      
  end
end

def run()
  ds = initDataStructure()
  iterationCycle = 1
#  while true
    warn "cycle: #{iterationCycle}"
    iterationCycle += 1
    @constraints.each do |constraint|
      # First, break down information
      # Second, apply rule
      # Third, see if inverse of rule applies
      applyConstraint(constraint, ds)
    end
#  end
   return ds
end

def lookupAttr(key, index)
  return "     " if index.nil?
  return @constants[key][index]
end

def prettyPrint(ds)
  warn "Here's what we know: "
  ds.each do |house|
    puts "\t For house: #{getHouseNum(house)}"
    house.each do |k,v|
      badLookup = ""
      v['bad'].each do |bad| 
        badLookup += lookupAttr(k,bad).to_s
      end
      puts "\t\t Attr: #{k} Good: #{lookupAttr(k,v['good'])}, \t\tBad: #{badLookup}"
    end
  end
end

prettyPrint(run())
