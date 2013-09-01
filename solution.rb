# http://en.wikipedia.org/wiki/Zebra_Puzzle#Step_1
# Usage: ruby solution.rb

#
# I saw there as being two major approaches to this problem.  You could either
#  1) Realize the search space for this one problem is rather small so brute
#     forcing a solution is computationally possible.  You'd then test these
#     attempts against the constraints OR
#  2) Attempt to create a constraint propagation system.  If this, then that.
#
#  I figured that (2) would be much more interesting to solve, though considerably
#  harder to create. If you include possibilities like customizable constraints 
#  (as opposed to hard coding them), and flexible paramters like number of houses
#  or values for fields like nationality, you make this considerably more difficult.
#  The neat thing though is that this solution will branch-and-bound considerably 
#  with the addition of these constraints, so you get a large speed up.
#
#  So let's talk about some of the overall concepts here. 
#  Key datastructure:  array of hashes
#    To keep everything straight, all of the known information if reflected relative to 
#    house numbers.  For example:
#    [{"number":{"good":0,"bad":[1,2,3,4]}]
#    Each entry in the array is a distinct house.  The different attributes of the house,
#    like nationality, are contained as sub-hases of the form <attr>:{"good":"","bad":[]}
#    So that we can keep track of the values that attribute can and cannot be. 
#  Algo:
#    We attempt to propogate the information contained in the constraints as much as
#    possible.  If we reach a point we can't and the puzzle is still unsolved, we 
#    randomly pick an unsolved attribute and set it to some arbitrary but legal value.
#    Then, we see if we can solve the puzzle by more propagation.  If we ever hit
#    an illegal state, we backtrack and try the next possible value. Rinse and repeat.
#  
#  Now that we've gotten that far, let's give in to some code.  I'll note where I might improve
#  the code if I were to productionize this.
require 'json' 

# The next 4 datastructures define the entire configuration of our system.
# IMPROVEMENT: Move these to some outside JSON and pass it in as a command line argument
# IMPROVEMENT: Add some more verification to confirm that these structures are self-consistent.
#   There's a lot that can go wrong if, for instance, we misspell "nationality" in the wrong place.
@numHouses = 5

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

# Here are the constraints, codified into a DSL.
# "==" means a house must have both of these properties or neither
# "next" means that the first property must be in a house adjacent to the second
# "+1" means the left attribute must be in the house before the right attribute.

# The numbers after the keys represent an array position in @constants.  They are used
# to cut down on the chance we'd mess one of those values up.
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
  "nationality/3 next color/3"
]


# Create the data structure discussed above.  Automatically populate the number field,
# since it's assumed from the house's position in the top-level array.
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

def getHouseNum(house)
  return house["number"]["good"]
end

# This is the only function we allow to set an attribute's "good" parameter.
def foundCertain(houseNum,key,value,ds)
  # If we're about to submit a value that would overwrite a previously established
  # value, raise an exception, since that's clearly a mistake
  if ds[houseNum][key]["good"].nil? || ds[houseNum][key]["good"] == value
    ds[houseNum][key]["good"] = value
  else
    raise "Incorrect overwrite for houseNum #{houseNum}, key #{key}: Set to #{value}"
  end
  # We should also set the "bad" value to every other possibility
  @numHouses.times do |index|
    foundFailure(houseNum, key, index, ds) if value != index
  end
  # And record that no other house can have this value
  ds.each do |house|
    foundFailure(getHouseNum(house), key, value, ds)  if getHouseNum(house) != houseNum
  end
end

# The only function allowed to record "bad" values.
# Throws exceptions for out of bounds errors
def foundFailure(houseNum,key,value,ds)
  if houseNum < 0 || houseNum >= @numHouses
    raise "Out of bounds error: House: #{houseNum}, Attr: #{key}, Val: #{value}"
  end
  # Don't add a value that's already there.
  # IMPROVEMENT: Use Sets for "bad"
  ds[houseNum][key]["bad"] << value if !ds[houseNum][key]["bad"].include?(value)
end

def isValueMatched?(currentValue, testValue)
  return !currentValue.nil? && currentValue != testValue
end

# Helper function for the "next" constraints.
# If houseNum is at either end of the houses, we can submit to the only neighbor
# If houseNum is in the middle and one of the neighbors is already determined 
#   for that key, we can populate the other neighbor
def foundNext(houseNum,key,value,ds)
  if houseNum == 0
    foundCertain(1, key,value,ds)
  elsif houseNum == @numHouses - 1
    foundCertain(@numHouses - 2, key,value,ds)
  else
    if isValueMatched?(ds[houseNum + 1][key]["good"], value)
      foundCertain(houseNum - 1, key, value, ds)
    elsif isValueMatched?(ds[houseNum - 1][key]["good"], value)
      foundCertain(houseNum + 1, key, value, ds)
    end
  end
end

# Constraints always have the form "key/number command key/number"
# Extract those values out for easy handling
def extractConstraint(constraint)
  captured = /([^\/]*)\/([^\s]*) [^\s]* ([^\/]*)\/([^\s]*)/.match(constraint)
  key1 = captured[1]
  value1 = captured[2].to_i
  key2 = captured[3]
  value2 = captured[4].to_i
  return key1,value1,key2,value2
end

# For the == case, check if either of the cases is satisfied in any house
# Or, if see if either cases is in "bad", and populate the other.
def evaluateConstraintEquals(ds, constraint)
  key1,value1,key2,value2,command = extractConstraint(constraint)
  ds.each do |house|
    if house[key2]["good"] == value2
      foundCertain(getHouseNum(house),key1,value1,ds)
    elsif house[key1]["good"] == value1
      foundCertain(getHouseNum(house),key2,value2,ds)
    end
    
    if isValueMatched?(house[key1]["good"],value1)
      foundFailure(getHouseNum(house),key2,value2,ds)
    elsif isValueMatched?(house[key2]["good"],value2)
      foundFailure(getHouseNum(house),key1,value1,ds)
    end
  end  
end

# for the next case, see if either of the neighbors of these properties hold
# IMPROVEMENT: Add case for when both neighbors are "bad"
def evaluateConstraintNext(ds, constraint)
  key1,value1,key2,value2,command = extractConstraint(constraint)
  ds.each do |house|
    if house[key2]["good"] == value2
      foundNext(getHouseNum(house),key1,value1,ds)
    elsif house[key1]["good"] == value1
      foundNext(getHouseNum(house),key2,value2,ds)
    end
  end
end

# for the +1 case, see if either property is true and populate the neighbor
# The first property can't be in the last house and vice versa
def evaluateConstraintPlusOne(ds,constraint)
  key1,value1,key2,value2 = extractConstraint(constraint)
  ds.each do |house|
    foundFailure(0,key2,value2,ds)
    foundFailure(@numHouses - 1, key1, value1, ds)
    
    if house[key2]["good"] == value2
      foundCertain(getHouseNum(house) - 1,key1,value1,ds)
    elsif house[key1]["good"] == value1
      foundCertain(getHouseNum(house) + 1,key2,value2,ds)
    end
    
    # And if we know the property is in "bad", we can populate the neighbor
    if isValueMatched?(house[key2]["good"],value2) && getHouseNum(house) != 0
      foundFailure(getHouseNum(house) - 1,key1,value1,ds)
    end
    if isValueMatched?(house[key1]["good"],value1) && getHouseNum(house) != @numHouses - 1
      foundFailure(getHouseNum(house) + 1,key2,value2,ds) 
    end
  end
end

# Interprets the constraints and acts on them accordingly
def applyConstraint(constraint, ds)
  if (/==/.match(constraint))
    evaluateConstraintEquals(ds, constraint)
  elsif (/next/.match(constraint))
    evaluateConstraintNext(ds, constraint)
  elsif (/\+1/.match(constraint))
    evaluateConstraintPlusOne(ds,constraint)
  end
end

# For all houses, if all but one value is in "bad", we know the value of "good"
def checkBads(ds)
  ds.each do |house|
    house.each do |attr,val|
      if val["bad"].length == @numHouses - 1
        # Creates all possible values and then removes the "bad" to get the "good"
        certainValue = ((0..@numHouses - 1).to_a - val["bad"])
        foundCertain(getHouseNum(house), attr, certainValue[0], ds)
      end
    end
  end
end

# Checks that every attribute of every house is set
# Returns false is that's not the case
def confirmComplete(ds)
  ds.each do |house|
    house.each do |attr,val|
      return false if val["good"].nil?
    end
  end
  return true
end

# Guesses a solution given the current state of the solver
# We only need to find one attribute that's not solved and iterate over that. 
# If nothing works for that attribute, no solution exists.
def assumeField(ds)
  attemptedField = false
  ds.each do |house|
    house.each do |attr,val|
      next if attemptedField
      if val["good"].nil?
        ((0..@numHouses - 1).to_a - val["bad"]).each do |available|
          attemptedField = true
          # This is a deep copy of the hash. Object.clone is shallow
          tempDS = JSON.parse(ds.to_json)
          foundCertain(getHouseNum(house),attr,available,tempDS)
          begin
            return run(tempDS)
          rescue Exception => e
            next
          end
        end
      end
    end
  end
end

# Runs constraints and checks to see if we've found a solution
# If we get stuck, takes a guess (recursively) and proceeds until a solution is 
# found or we've proved no solution exists.
def run(ds = nil)
  ds = initDataStructure() if ds.nil?
  
  #oldDS saves our progress each cycle
  oldDS = prettyPrint(ds)
  
  while (true)
    @constraints.each do |constraint|
      applyConstraint(constraint, ds)
    end
    checkBads(ds)
    
    # Check our progress.  If we haven't changed, see if we're done.
    if oldDS == prettyPrint(ds)
      if !confirmComplete(ds)
        ds = assumeField(ds)
      end
      # If we've tried all attributes and nothing worked, no solution exists
      raise "no solution available" if !confirmComplete(ds)
      return ds
    else
      oldDS = prettyPrint(ds)
    end
  end
end

# Given an attribute type and the index, looks up the human readable name
def lookupAttr(key, index)
  return " " if index.nil?
  return @constants[key][index]
end

# Makes the datastructure easier to read
def prettyPrint(ds, final = false)
  returnString = "Here's what we know: \n"
  ds.each do |house|
    returnString +=  "\t For house: #{getHouseNum(house)}\n"
    house.each do |k,v|
      badLookup = []
      v['bad'].each do |bad| 
        badLookup << lookupAttr(k,bad).to_s
      end
      if final
        returnString +=  "\t\t Attr: #{k} Good: #{lookupAttr(k,v['good'])}\n"
      else
        returnString +=  "\t\t Attr: #{k} Good: #{lookupAttr(k,v['good'])}, \t\tBad: #{badLookup.join(',')}\n"
      end
    end
  end
  return returnString
end

bTime = Time.now 
puts prettyPrint(run(), true)
warn "TIME: #{Time.now - bTime}"
