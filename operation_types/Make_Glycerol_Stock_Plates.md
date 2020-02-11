# Make Glycerol Stock Plates

This protocol will show you how to prepare glycerol stock plates in a High Throughput Plate.
This operation also transfers the culture conditions and an experimental materials list for that given collection of glycerol stocks.

    1. Gather materials and label new containers.
    
    2. Pre-fill collection with glycerol and resuspend culture at a 1:1 ratio.
    
    3. Store plates at -80#{DEGREES_C}
### Inputs


- **Culture Plate** [P]  
  - NO SAMPLE TYPE / <a href='#' onclick='easy_select("Containers", "Eppendorf 96 Deepwell Plate")'>Eppendorf 96 Deepwell Plate</a>

### Parameters

- **Delete Input Plate** [Yes, No]

### Outputs


- **Glycerol Stock Plate** [GP] (Array) 
  - NO SAMPLE TYPE / <a href='#' onclick='easy_select("Containers", "96 Well PCR Plate")'>96 Well PCR Plate</a>

### Precondition <a href='#' id='precondition'>[hide]</a>
```ruby
def precondition(_op)
  true
end
```

### Protocol Code <a href='#' id='protocol'>[hide]</a>
```ruby
needs "Standard Libs/Debug"
needs "Standard Libs/Units"
needs "Tissue Culture Libs/CollectionDisplay"
needs "High Throughput Culturing/HighThroughputHelper"
needs "High Throughput Culturing/CultureComposition"

class Protocol
  include Debug, Units
  include CollectionDisplay
  include HighThroughputHelper
  
  # DEF 
  INPUT  = "Culture Plate"
  OUTPUT = "Glycerol Stock Plate"
  INPUT_DELETE = "Delete Input Plate"
  
  # Constants
  GLYCEROL_PER_WELL = 20#ul
  CULTURE_PER_WELL  = 20#ul
  
  def intro
    show do 
      title "Making Glycerol Stock Plates"
      separator
      note "This protocol will show you how to prepare glycerol stock plates in a High Throughput Plate."
      note "This operation also transfers the culture conditions and an experimental materials list for that given collection of glycerol stocks."
      note "<b>1.</b> Gather materials and label new containers."
      note "<b>2.</b> Pre-fill collection with glycerol and resuspend culture at a 1:1 ratio."
      note "<b>3.</b> Store plates at -80#{DEGREES_C}"
    end
  end
  
  # Access class variables via Protocol.your_class_method
  @materials_list = []
  def self.materials_list; @materials_list; end
  
  def main
    intro
    operations.make
    operations.each do |op| 
      input_collection = op.input(INPUT).collection
      # stamp transfer part data from input collection to all of the collections in the output array
      output_glycerol_stock_plates = op.output_array(OUTPUT).collections
      output_glycerol_stock_plates.each do |glycerol_stock_plate|
        part_data_matrix = stamp_transfer(from_collection: input_collection, to_collection: glycerol_stock_plate, process_name: 'Aliquot')
        glycerol_stock_plate.associate(key='experimental_materials_list', value=get_experimental_materials_list(part_data_matrix))
        gather_materials(empty_containers: [glycerol_stock_plate], transfer_required: false, new_materials: ["50% Glycerol", "Aluminum Adhesive Seals"], take_items: [])
        prepare_seal(glycerol_stock_plate)
        prepare_multichannel_stripwell(glycerol_stock_plate)
        pre_fill_glycerol_stock_plate(glycerol_stock_plate)
        transfer_culture_and_inoculate(input_collection: input_collection, glycerol_stock_plate: glycerol_stock_plate)
        glycerol_stock_plate.location = "-80#{DEGREES_C} Freezer"
        glycerol_stock_plate.save
      end
      if op.input(INPUT_DELETE) == "Yes"
        input_collection.mark_as_deleted # TODO: Add keep plate parameter!!
      end
    end
    cleaning_up
    {operations: operations}
  end # main
  
  def cleaning_up
    show do
      title "Cleaning Up..."
      separator
      note "Make sure trash is placed in the proper disposal."
      note "Make sure that #{operations.map {|op| op.inputs[0].collection.id}} plates are placed in the sink and soaked with bleach."
    end
    operations.store
  end
  
  def transfer_culture_and_inoculate(input_collection:, glycerol_stock_plate:)
    show do 
      title "Transfer Cultures from #{input_collection} to #{glycerol_stock_plate}"
      separator
      warning "Make sure both plates are in the same orientation."
      note "Transfer and resuspend, #{CULTURE_PER_WELL}#{MICROLITERS} per culture."
      note "<b>From #{input_collection} #{input_collection.object_type.name}"
      note "<b>To #{glycerol_stock_plate} #{glycerol_stock_plate.object_type.name}"
      bullet "Resuspend 5 times"
      note "Take a labeled aluminum adhesive and use it to seal the #{glycerol_stock_plate.object_type.name} #{glycerol_stock_plate.id}."
      check "Finally, set aside until all plates are prepared."
    end
  end

  def pre_fill_glycerol_stock_plate(glycerol_stock_plate)
    show do
      title "Fill #{glycerol_stock_plate} #{glycerol_stock_plate.object_type.name}"
      separator
      note "Follow the table below to pre-fill the glycerol stock plate with <b>50% glycerol</b>:"
      bullet "Use a multichannel pipette where convenient"
      table highlight_alpha_non_empty(glycerol_stock_plate) {|r,c| "#{GLYCEROL_PER_WELL}#{MICROLITERS}" }
    end
  end
  
  def prepare_seal(glycerol_stock_plate)
    show do
      title "Prepare Label"
      separator
      check "Take an Aluminum Seal"
      check "Label the seal with the following:"
      bullet "GSP #{glycerol_stock_plate.id}"
      bullet "Today's Date"
      bullet "Your Initials"
      check "Set aside until you are ready to seal the prepared plate."
    end
  end
  
  def get_total_glycerol_volume_ul(collection)
    HighThroughputHelper.add_extra_vol(int: collection.get_non_empty.length*GLYCEROL_PER_WELL)
  end
  
  def get_total_glycerol_volume_ml(glycerol_ul)
    (glycerol_ul/1000.0).round(2)
  end
  
  def prepare_multichannel_stripwell(collection)
    sw, aliquot_matrix, rc_list = multichannel_vol_stripwell(collection)
    show do
      title "Prepare Multichannel Stripwell"
      separator
      check "Gather a 12-Well Stripwell & Holder"
      check "Gather a P100 or P200 Pipette"
      check "You will need #{get_total_glycerol_volume_ml(get_total_glycerol_volume_ul(collection))}#{MILLILITERS} of <b>50% glycerol</b>."
      note "Next, follow the table below to fill the appropriate amount of <b>50% glycerol</b> into each well of the stripwell:"
      table highlight_alpha_rc(sw, rc_list) {|r, c| "#{ HighThroughputHelper.add_extra_vol(int: aliquot_matrix[r][c]*GLYCEROL_PER_WELL).round(2) }#{MICROLITERS}" }
      bullet "Give a quick spindown to avoid air bubbles!"
      check "Gather a P20 Multichannel Pipette"
    end
    sw.mark_as_deleted
  end
  
  # Used for multichannel pipetting, creates a stripwell to display with the number of aliquots of the desired reagents
  #
  # @params collection [colleciton obj] is the collection that you be aliquoting reagent to
  # @returns sw [collection obj] the stripwell obj that will be used to display
  # @returns aliquot_matrix [2D-Array] is the matrix that contains the information of how many aliquots of reagents go in each well
  # @returns rc_list [Array] is a list of [r,c] tuples that will be used to display which wells are to be used for aliquots
  def multichannel_vol_stripwell(collection)
      # Create a stripwell to display
      sw = make_stripwell
      # Create a matrix the size of the stripwell
      aliquot_matrix = Array.new(sw.object_type.rows) { Array.new(sw.object_type.columns) {0} }
      collection.get_non_empty.each {|r, c| aliquot_matrix[0][c] += 1}
      rc_list = []
      aliquot_matrix.each_with_index {|row, r_i| row.each_with_index {|col, c_i| (col == 0) ? EMPTY : rc_list.push([r_i, c_i]) } }
      return sw, aliquot_matrix, rc_list
  end    
  
  def make_stripwell
    sw_obj_type = ObjectType.find_by_name('stripwell')
    sw = Collection.new()
    sw.object_type_id = sw_obj_type.id
    sw.apportion(sw_obj_type.rows, sw_obj_type.columns)
    sw.quantity = 1
    return sw
  end
  
  
  def get_experimental_materials_list(part_data_matrix)
    materials_hash = nested_hash_data_structure
    part_data_matrix.flatten.reject {|composition| composition.nil? }.each do |composition|
      composition.each do |component_type, sample_attr|
        if ['Media', 'Inducer(s)', 'Antibiotic(s)'].include? component_type
          sample_attr.each do |sname, attributes|
            item_id   = attributes.fetch(:item_id)
            wk_volume = attributes.fetch(:working_volume)
            ot_name = Item.find(item_id).object_type.name
            if materials_hash[component_type][sname][ot_name].empty?
              materials_hash[component_type][sname][ot_name] = wk_volume
            else
              current_wk_volume = materials_hash[component_type][sname][ot_name]
              if current_wk_volume.fetch(:units) == wk_volume.fetch(:units)
                wk_volume[:qty] = (current_wk_volume.fetch(:qty) + wk_volume.fetch(:qty)).round(3)
                materials_hash[component_type][sname][ot_name] = wk_volume
              else
                # TODO: Consider how to handle different units different units
                # if (1/CultureComponent.unit_conversion_hash[current_wk_vol.fetch(:units)]) < (1/CultureComponent.unit_conversion_hash[wk_volume.fetch(:units)])
                raise "The current working volume #{current_wk_volume} does not have the same units as the new additional working volume #{wk_volume}"
              end
            end
          end
        end
      end
    end
    return materials_hash
  end  
end # protocol
```
