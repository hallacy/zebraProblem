# http://en.wikipedia.org/wiki/Zebra_Puzzle#Step_1
require 'json' 
require 'hashdiff'

@constraints = [
  "nationality/0 == color/2",
  "nationality/1 == pet/1",
  "drink/0 == color/1",
  "nationality/2 == drink/3",
  "color/0 +1 color/1",
  "smoke/0 == pet/2",
  "smoke/1 == color/4",
  "drink/1 == number/2",
  "nationality/3 == number/0",
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
  if ds[houseNum][key]["good"].nil? || ds[houseNum][key]["good"] == value
    ds[houseNum][key]["good"] = value
  else
    raise "you've reached an incorrect solution"
  end
  @numHouses.times do |index|
    foundFailure(houseNum, key, index, ds) if !ds[houseNum][key]["bad"].include?(index) && value != index
  end
  ds.each do |house|
    if getHouseNum(house) != houseNum && !house[key]["bad"].include?(value)
      foundFailure(getHouseNum(house), key, value, ds)
    end
  end
end

def foundFailure(houseNum,key,value,ds)
  if houseNum < 0 || houseNum >= @numHouses
    raise "out of bounds"
  end
  ds[houseNum][key]["bad"] << value if !ds[houseNum][key]["bad"].include?(value)
end

# If houseNum is at the end, go in 1.
# If houseNum is in the middle and one of the neighbors is already determined for that key, populate the other one
def foundNext(houseNum,key,value,ds)
  if houseNum == 0
    foundCertain(1, key,value,ds)
  elsif houseNum == @numHouses - 1
    foundCertain(3, key,value,ds)
  else
    if !ds[houseNum + 1][key]["good"].nil? && ds[houseNum + 1][key]["good"] != value
      foundCertain(houseNum - 1, key, value, ds)
    elsif !ds[houseNum - 1][key]["good"].nil? && ds[houseNum - 1][key]["good"] != value
      foundCertain(houseNum + 1, key, value, ds)
    end
  end
end

def getHouseNum(house)
  return house["number"]["good"]
end

def applyConstraint(constraint, ds)
  if (/==/.match(constraint))
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
      if !house[key1]["good"].nil? && house[key1]["good"] != value1
        foundFailure(getHouseNum(house),key2,value2,ds)
      elsif !house[key2]["good"].nil? && house[key2]["good"] != value2
        foundFailure(getHouseNum(house),key1,value1,ds)
      end
    end      
  elsif (/next/.match(constraint))
   # for the next case, see if either of the neighbors of these properties hold
    captured = /([^\/]*)\/([^\s]*) next ([^\/]*)\/([^\s]*)/.match(constraint)
    key1 = captured[1]
    value1 = captured[2].to_i
    key2 = captured[3]
    value2 = captured[4].to_i
    ds.each do |house|
      if house[key2]["good"] == value2
        foundNext(getHouseNum(house),key1,value1,ds)
      elsif house[key1]["good"] == value1
        foundNext(getHouseNum(house),key2,value2,ds)
      end
    end
  elsif (/\+1/.match(constraint))
   # for the next case, see if either of the neighbors of these properties hold
    captured = /([^\/]*)\/([^\s]*) \+1 ([^\/]*)\/([^\s]*)/.match(constraint)
    key1 = captured[1]
    value1 = captured[2].to_i
    key2 = captured[3]
    value2 = captured[4].to_i
    ds.each do |house|
      foundFailure(0,key2,value2,ds)
      foundFailure(@numHouses - 1, key1, value1, ds)
      if house[key2]["good"] == value2
        foundCertain(getHouseNum(house) - 1,key1,value1,ds)
      elsif house[key1]["good"] == value1
        foundCertain(getHouseNum(house) + 1,key2,value2,ds)
      end
      if !house[key2]["good"].nil? && house[key2]["good"] != value2 && getHouseNum(house) != 0
        foundFailure(getHouseNum(house) - 1,key1,value1,ds)
      end
      if !house[key1]["good"].nil? && house[key1]["good"] != value1 && getHouseNum(house) != @numHouses - 1
        foundFailure(getHouseNum(house) + 1,key2,value2,ds) 
      end
    end
  end
end

def checkBads(ds)
  ds.each do |house|
    house.each do |attr,val|
      if val["bad"].length == @numHouses - 1
        certainValue = ((0..@numHouses - 1).to_a - val["bad"])
        foundCertain(getHouseNum(house), attr, certainValue[0], ds)
      end
    end
  end
end

def run(ds = nil)
  ds = initDataStructure() if ds.nil?
  oldDS = prettyPrint(ds)
  iterationCycle = 1
  while (true)
    warn "CYCLE: #{iterationCycle}"
    iterationCycle += 1
    @constraints.each do |constraint|
      # First, break down information
      # Second, apply rule
      # Third, see if inverse of rule applies
      applyConstraint(constraint, ds)
    end
    checkBads(ds)
    if oldDS == prettyPrint(ds)
      finished = confirmComplete(ds)
      # if we've reached a point where we can no longer populate attributes but we're not finished, take a guess
      if !finished
        attemptedField = false
        ds.each do |house|
          house.each do |attr,val|
            next if attemptedField
            if val["good"].nil?
              ((0..@numHouses - 1).to_a - val["bad"]).each do |available|
                attemptedField = true
                tempDS = JSON.parse(ds.to_json)
                warn "ASSUMING: house #{getHouseNum(house)}, attr #{attr}, value: #{lookupAttr(attr,available)}"
                foundCertain(getHouseNum(house),attr,available,tempDS)
                begin
                  return run(tempDS)
                 
                rescue Exception => e
                  tempDS[getHouseNum(house)][attr]["good"] = nil
                  warn "TRYING NEXT ASSUMPTION: #{e}"
                  next
                end
              end
            end
          end
        end
      end
      raise "no solution available" if !confirmComplete(ds)
      return ds
    else
      oldDS = prettyPrint(ds)
    end
  end
end

def confirmComplete(ds)
  ds.each do |house|
    house.each do |attr,val|
      return false if val["good"].nil?
    end
  end
end

def lookupAttr(key, index)
  return "     " if index.nil?
  return @constants[key][index]
end

def prettyPrint(ds)
  returnString = "Here's what we know: \n"
  ds.each do |house|
    returnString +=  "\t For house: #{getHouseNum(house)}\n"
    house.each do |k,v|
      badLookup = []
      v['bad'].each do |bad| 
        badLookup << lookupAttr(k,bad).to_s
      end
      returnString +=  "\t\t Attr: #{k} Good: #{lookupAttr(k,v['good'])}, \t\tBad: #{badLookup.join(',')}\n"
    end
  end
  return returnString
end

bTime = Time.now 
puts prettyPrint(run())
warn "TIME: #{Time.now - bTime}"
