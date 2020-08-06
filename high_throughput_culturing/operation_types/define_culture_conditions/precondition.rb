
def precondition(_op)
    op = Operation.find(_op.id)
    # Check to see whether the parameter value is JSON parasable before starting
    op.field_values.select {|fv| fv.role == 'input' }.each do |fv|
      if ["Strain", "Media", "Replicates"].include? fv.name
        next # These field values are not JSON parameters
      else
        valid_json?(fv.value)
      end
    end
    op.pass("Strain", "Culture Condition")
    # set status to done, so this block will not be evaluated again
    op.status = "done"
    op.save
end

def valid_json?(json)
    JSON.parse(json) rescue raise "Not at parsable json: #{json}" # JSON::ParserError => e
end
