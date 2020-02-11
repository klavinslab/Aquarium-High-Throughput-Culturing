# Apply Experimental Condition

This operation takes in a culture plate collection applies a reagent, timestamps the collection, and passes it as an output. The operation uses the experimental condition chosen by the user as a key. The key is then used to generate data structures for displaying specific wells in a collection. Furthermore, the key is also used to fetch how much volume of the experimental condition item (ie: inducers or antibiotics) each well requires. Future directions may be to include using the Option(s) key to apply custom experimental conditions (ie: Ethanol, Cellular Stain). The option(s) parameter can be input into the Define Culture Conditions operation as a JSON parsable object.
### Inputs


- **Culture Plate** [P] (Array) 
  - NO SAMPLE TYPE / <a href='#' onclick='easy_select("Containers", "Eppendorf 96 Deepwell Plate")'>Eppendorf 96 Deepwell Plate</a>
  - NO SAMPLE TYPE / <a href='#' onclick='easy_select("Containers", "24 Unit Disorganized Collection")'>24 Unit Disorganized Collection</a>

### Parameters

- **Experimental Condition** [Media,Antibiotic(s),Inducer(s),Option(s)]

### Outputs


- **Experimental Plate** [P] (Array) 
  - NO SAMPLE TYPE / <a href='#' onclick='easy_select("Containers", "Eppendorf 96 Deepwell Plate")'>Eppendorf 96 Deepwell Plate</a>
  - NO SAMPLE TYPE / <a href='#' onclick='easy_select("Containers", "24 Unit Disorganized Collection")'>24 Unit Disorganized Collection</a>

### Precondition <a href='#' id='precondition'>[hide]</a>
```ruby
def precondition(_op)
  true
end
```

### Protocol Code <a href='#' id='protocol'>[hide]</a>
```ruby
# By: Eriberto Lopez
# elopez3@uw.edu
# 07/09/19

needs "Standard Libs/Debug"
needs "Tissue Culture Libs/CollectionDisplay"
needs "High Throughput Culturing/CultureComposition"
needs "High Throughput Culturing/HighThroughputHelper"

class Protocol
  include Debug
  include CollectionDisplay
  include HighThroughputHelper
  
  # DEF
  INPUT = "Culture Plate"
  OUTPUT = "Experimental Plate"
  EXPERIMENTAL_CONDITION = "Experimental Condition"

  def intro
    show do
      title "Apply Experimental Condition"
      separator
      note "This protocol will guide you through applying an experiment condition (ie: Inducer(s), Antibiotic(s), etc...) to a high throughput plate."
      note ""
      note "<b>1.</b> Gather materials for experiment."
      note "<b>2.</b> Fill a multichannel stripwell with input items."
      note "<b>3.</b> Using a multichannel pipette, transfer from the multichannel stripwell to the collection."
      note "<b>4.</b> Label with condition applied and the date & time."
      note "<b>5.</b> Incubate."
    end
  end
  
  def main
    intro
    clean_up_array = []
    operations.each do |op|
      experimental_condition = op.input(EXPERIMENTAL_CONDITION).val
      op = Operation.find(178796) if debug
      op.input_array(INPUT).collections.each_with_index do |collection, idx|
        collection_associations = AssociationMap.new(collection)
        part_data_matrix = get_part_data_matrix(collection_associations)
        # experimental condition input items taken from attributes associated to collection parts
        item_id_to_rc_list = get_item_id_to_rc_list(part_data_matrix: part_data_matrix, experimental_condition: experimental_condition)
        show {note "<b>In the follow steps gather #{experimental_condition} and let thaw at room temperature."} unless item_id_to_rc_list.empty?
        input_items = Item.find(item_id_to_rc_list.keys.map {|i| i.to_i}); take input_items, interactive: true; clean_up_array.push(input_items)
        item_id_to_rc_list.each do |item_id, rc_to_volume|
          experimental_component_item = Item.find(item_id)
          if experimental_condition == "Option(s)"
            optional_item = Item.find(item_id)
            show do
              title "Optional Experimental Condition"
              separator
              note "Using the following slides to guide yourself in setting up the optional parameters of this experiment."
              table highlight_alpha_rc(collection, rc_to_volume.keys){|r,c| "#{optional_item.sample.name}\n#{rc_to_volume[[r,c]][:qty]}\n#{rc_to_volume[[r,c]][:units]}"}
            end
          else
            total_working_volume = get_total_item_working_volume(rc_to_volume) 
            if total_working_volume[:qty] > 0
              show do
                title "Dispense item #{item_id} into #{collection} #{collection.object_type.name}"
                separator
                note "<b>For the next step you will need:</b>"
                bullet "#{(total_working_volume[:qty]).round(3)}#{total_working_volume[:units]} of #{experimental_component_item.sample.name} #{experimental_component_item.object_type.name}"
                note "<b>Follow the table below to dispense the appropriate amount of item #{item_id} into the #{collection.object_type.name}:</b>"
                table highlight_alpha_rc(collection, rc_to_volume.keys) {|r,c| 
                  wk_volume = rc_to_volume[[r,c]]
                  "#{wk_volume.fetch(:qty)}#{wk_volume.fetch(:units)}"
                }
              end
            end
          end
        end
        associate_applied_condition(collection_associations: collection_associations, experimental_condition: experimental_condition)
        op.output_array(OUTPUT)[idx].set collection: collection
      end
    end
    clean_up(item_arr: clean_up_array.flatten.uniq)
  end # main

  def get_part_data_matrix(collection_associations)
    return collection_associations.instance_variable_get(:@map).select {|key| key == 'part_data' }.values.first
  end
  
  def associate_applied_condition(collection_associations:, experimental_condition:)
    applied_conditions = collection_associations.get('applied_conditions') 
    if applied_conditions
      applied_conditions.push({experimental_condition: experimental_condition, time: timestamp})
    else
      applied_conditions = [{experimental_condition: experimental_condition, time: timestamp}]
    end
    collection_associations.put(key='applied_conditions', value=applied_conditions)
    collection_associations.save
  end
  
  def display_multichannel_stripwell(sw, sw_vol_mat, rc_list, item_id, total_working_volume)
    show do
      title "Aliquot #{item_id} into Multichannel Stripwell"
      separator
      note "Follow the table below to aliquot #{item_id} into a multichannel format:"
      table highlight_alpha_rc(sw, rc_list) {|r,c| "#{sw_vol_mat[r][c]}#{total_working_volume[:units]}"}
      bullet "If this buffer has an enzyme keep stripwell on ice (ie: qPCR Master Mix)"
    end
  end
  
  def timestamp
    timepoint = Time.now()
    day = timepoint.strftime "%m%d%Y"
    hour = timepoint.strftime "%H%M"
    return "#{day} - #{hour}"
  end
  
  def make_multichannel_stripwell(collection:, rc_to_volume:)
    # Create a stripwell to display
    sw = produce new_collection 'Stripwell'
    # Create a matrix the size of the stripwell
    sw_vol_mat = Array.new(sw.object_type.rows) { Array.new(sw.object_type.columns) {0} }
    rc_to_volume.keys.each {|r, c| sw_vol_mat[0][r] += rc_to_volume.fetch([r,c]).fetch(:qty) }
    rc_list = []
    sw_vol_mat.each_with_index {|stripwell, r_i| 
      stripwell.each_with_index {|well_vol, w_idx| rc_list.push([0, w_idx]) if (well_vol > 0) }
    }
    return sw, sw_vol_mat, rc_list
  end
  
  # TODO: how to handle changing units and adding - use HighThroughputHelper.unit_conversion_hash
  def get_total_item_working_volume(rc_to_volume)
    total_working_volume = {qty: 0, units: MICROLITERS}
    rc_to_volume.values.each do |wk_volume| 
      if wk_volume.fetch(:units) == total_working_volume.fetch(:units)
        total_working_volume[:qty] += wk_volume[:qty]
      else 
        raise 'not the same units!!'
      end
    end
    return total_working_volume
  end
    
  def get_item_id_to_rc_list(part_data_matrix:, experimental_condition:)
    item_id_to_rc_list = Hash.new()
    if experimental_condition != "Option(s)"
        part_data_matrix.each_with_index do |row, r_i|
          row.each_with_index do |part_data, c_i|
            culture_component = part_data.fetch(experimental_condition, {})
            culture_component.each do |sname, attributes|
              item_id   = attributes.fetch(:item_id)
              wk_volume = attributes.fetch(:working_volume)
              (item_id_to_rc_list.keys.include? item_id) ? item_id_to_rc_list[item_id].merge!({[r_i, c_i]=>wk_volume}) : item_id_to_rc_list[item_id] = {[r_i, c_i]=>wk_volume}
            end
          end
        end
    else
      option_items_hash = {}
      available_option_keys = part_data_matrix.map {|row| row.map {|part| part.fetch(experimental_condition, {}) } }.flatten.uniq.reject{|part| part.empty? }.map {|part| part.keys.first}.uniq 
      option_key = show do
        title "Choose the key of what you would like to apply"
        select available_option_keys, var: 'option', label: "Select what experimental condition you want to apply in this operation.", default: 0
      end
      part_data_matrix.each_with_index do |row, r_i|
        row.each_with_index do |part, c_i|
          culture_component = part.fetch(experimental_condition, {}).fetch(option_key[:option], {})
          if !culture_component.empty?
            culture_component.each do |sname, attributes|
              if option_items_hash.keys.include? sname
                option_item = option_items_hash[sname]
              else
                option_sample = Sample.find_by_name(sname)
                option_item = option_sample.items.reject {|i| i.location == 'deleted'}.first
                option_items_hash[sname] = option_item
              end
              fconc = attributes.fetch(:final_concentration, {qty: 0, units: 'NONE'})
              item_id = option_item.id
              (item_id_to_rc_list.keys.include? item_id) ? item_id_to_rc_list[item_id].merge!({[r_i, c_i]=>fconc}) : item_id_to_rc_list[item_id] = {[r_i, c_i]=>fconc}
            end
          end
        end
      end
    end
    return item_id_to_rc_list
  end
end # protocol

```
