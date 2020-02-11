# Experimental Recovery

This protocol will guide you on how to recover your growing cultures and prepare the next plate for your experiment.

    1. Gather necessary materials.
    
    2. Pre-fill new plate with media(s).
    
    3. Stamp transfer plate wells to pre-filled new plate.
    
    4. Incubate.
### Inputs


- **Culture Plate** [P] (Array) 
  - NO SAMPLE TYPE / <a href='#' onclick='easy_select("Containers", "Eppendorf 96 Deepwell Plate")'>Eppendorf 96 Deepwell Plate</a>
  - NO SAMPLE TYPE / <a href='#' onclick='easy_select("Containers", "24 Unit Disorganized Collection")'>24 Unit Disorganized Collection</a>

### Parameters

- **Dilution** [0.5X, 0.2X,0.1X, 0.01X,0.001X]
- **When to recover? (24hr)** 

### Outputs


- **Diluted Plate** [P] (Array) 
  - NO SAMPLE TYPE / <a href='#' onclick='easy_select("Containers", "Eppendorf 96 Deepwell Plate")'>Eppendorf 96 Deepwell Plate</a>
  - NO SAMPLE TYPE / <a href='#' onclick='easy_select("Containers", "24 Unit Disorganized Collection")'>24 Unit Disorganized Collection</a>

### Precondition <a href='#' id='precondition'>[hide]</a>
```ruby
# This operation should be wired to only after inoculate culture plate
def precondition(_op)
  true # This operation should be wired to only after inoculate culture plate
end
```

### Protocol Code <a href='#' id='protocol'>[hide]</a>
```ruby
# By: Eriberto Lopez
# elopez3@uw.edu
# 080619

needs "Standard Libs/Debug"
needs "High Throughput Culturing/HighThroughputHelper"

class Protocol
  include HighThroughputHelper
  include Debug
  
  #DEF
  INPUT = "Culture Plate"
  OUTPUT = "Diluted Plate"
  DILUTION = "Dilution"
  OUTGROWTH = "Outgrowth (hr)"
  OPTIONS = "Option(s)"

  # Access class variables via Protocol.your_class_method
  @materials_list = []
  def self.materials_list; @materials_list; end
  
  def intro
    show do
      title "High Throughput Culturing Recovery"
      separator
      note "This protocol will guide you on how to recover your growing cultures and prepare the next plate for your experiment."
      note "<b>1.</b> Gather necessary materials."
      note "<b>2.</b> Pre-fill new plate with media(s)."
      note "<b>3.</b> Stamp transfer plate wells to pre-filled new plate."
      note "<b>4.</b> Incubate."
    end
  end
  
  def main
    intro
    operations.retrieve.make
    clean_up_arr = []
    operations.each do |op|
      dilution_factor = get_dilution_factor(op: op, fv_str: DILUTION)
      op.input_array(INPUT).collections.zip(op.output_array(OUTPUT).collections).each do |from_collection, to_collection|
        raise "Not enough output plates have been planned please add an output field value to this operation: Plan #{op.plan.id} Operation #{op.id}." if to_collection.nil?
        # Tranfer culture information and record PartProvenance
        part_associations_matrix = stamp_transfer(from_collection: from_collection, to_collection: to_collection, process_name: "Dilution")
        gather_materials(empty_containers: [to_collection], new_materials: ['Multichannel Pipette', 'Media Reservoir'], take_items: [])
        # Account and gather materials for the output collection
        transfer_vol_matrix = get_transfer_volume_matrix(collection: from_collection, part_associations_matrix: part_associations_matrix, dilution_factor: dilution_factor)
        pre_fill_collection(out_collection: to_collection, part_associations_matrix: part_associations_matrix, transfer_vol_matrix: transfer_vol_matrix)
        transfer_and_dilute_cultures(in_collection: from_collection, out_collection: to_collection, transfer_vol_matrix: transfer_vol_matrix)
        # Delete input collection and move output collection to incubator
        incubator_loc = from_collection.location
        to_collection.location = incubator_loc
        to_collection.save()
        from_collection.mark_as_deleted
      end
      clean_up(item_arr: clean_up_arr)
      operations.store
    end
  end #main
  
  def pre_fill_collection(out_collection:, part_associations_matrix:, transfer_vol_matrix:)
    media_hash = get_component_volume_hash(matrix: part_associations_matrix, component_type: "Media")
    show do 
      title "Pre-fill #{out_collection.object_type.name} #{out_collection} with Media"
      separator
      note "You will need the following amount of media:"
      media_hash.each {|media, volume| check "<b>#{(volume/1000).round(2)}#{MILLILITERS}</b> of <b>#{media} #{Item.find(media).sample.name}</b>"}
    end
    
    media_position_hash = {}
    part_associations_matrix.each_with_index do |row, r_i|
      row.each_with_index do |part, c_i|
        media_attribute = part.fetch("Media", false)
        if media_attribute
          if !media_attribute.nil? || !media_attribute.empty?
            media_name = media_attribute.keys.first
            position = [r_i, c_i]
            (media_position_hash.keys.include? media_name) ? (media_position_hash[media_name].push(position)) : (media_position_hash[media_name] = [position])
          end
        end
      end
    end
    
    media_position_hash.each do |media_name, rc_list|
      show do 
        title "Pre-fill #{out_collection.object_type.name} #{out_collection} with Media"
        separator
        note "Follow the table below to prefill #{out_collection.id} with #{media_name}:"
        table highlight_alpha_rc(out_collection, rc_list) {|r, c|
          media_component = part_associations_matrix[r][c].fetch("Media").values.first
          m_vol = media_component.fetch(:working_volume)
          m_vol[:qty] = m_vol[:qty] - transfer_vol_matrix[r][c]
          "#{format_collection_display_str(m_vol)}" 
        }
      end
    end
  end
  
  def transfer_and_dilute_cultures(in_collection:, out_collection:, transfer_vol_matrix:)
    show do 
      title "Transfer Cultures from #{in_collection} to #{out_collection}"
      separator
      note "Transfer cultures:"
      bullet "<b>From #{in_collection.object_type.name} #{in_collection}</b>"
      bullet "<b>To #{out_collection.object_type.name} #{out_collection}</b>"
      note "Follow the table to transfer the appropriate volume:"
      table highlight_alpha_non_empty(out_collection) {|r, c| "#{transfer_vol_matrix[r][c]}#{MICROLITERS}"}
    end
  end
  
  def copy_sample_matrix(from_collection:, to_collection:)
    sample_matrix = from_collection.matrix
    to_collection.matrix = sample_matrix
    to_collection.save()
  end
  
  def transfer_part_associations(from_collection:, to_collection:)
    copy_sample_matrix(from_collection: from_collection, to_collection: to_collection)
    from_collection_associations = AssociationMap.new(from_collection)
    to_collection_associations   = AssociationMap.new(to_collection)
    from_associations_map = from_collection_associations.instance_variable_get(:@map)
    # Remove previous source data from each part
    from_associations_map.reject! {|k| k != 'part_data'} # Retain only the part_data, so that global associations do not get copied over
    from_associations_map.fetch('part_data').map! {|row| row.map! {|part| part.key?("source") ? part.reject! {|k| k == "source" } : part } }
    from_associations_map.fetch('part_data').map! {|row| row.map! {|part| part.key?("destination") ? part.reject! {|k| k == "destination" } : part } }
    # log_info 'from_associations_map part_data with out source and destination', from_associations_map
    # Set edited map to the destination collection_associations
    to_collection_associations.instance_variable_set(:@map, from_associations_map)
    to_collection_associations.save()
    return from_associations_map
  end    
    
  def part_provenance_transfer(from_collection:, to_collection:, process_name:)
    to_collection_part_matrix = to_collection.part_matrix
    from_collection.part_matrix.each_with_index do |row, r_i|
      row.each_with_index do |from_part, c_i|
        if from_part
            to_part = to_collection_part_matrix[r_i][c_i]
            # Create source and destination objs
            source_id = from_part.id; source = [{id: source_id }]
            destination_id = to_part.id; destination = [{id: destination_id }]
            destination.first.merge({additional_relation_data: { process: process_name }}) unless process_name.nil?
            # Association source and destination
            to_part.associate(key=:source, value=source)
            from_part.associate(key=:destination, value=destination)
        end
      end
    end
  end
  
  def stamp_transfer(from_collection:, to_collection:, process_name: nil)
    from_associations_map = transfer_part_associations(from_collection: from_collection, to_collection: to_collection)
    part_provenance_transfer(from_collection: from_collection, to_collection: to_collection, process_name: process_name)
    return from_associations_map.fetch('part_data')
  end

  def get_component_volume_hash(matrix:, component_type:)
    volume_hash = Hash.new(0)
    matrix.each do |culture_array|
      culture_array.each do |culture|
        component = culture.fetch(component_type, nil)
        if component
          attributes = component.values.first
          item_id = attributes.fetch(:item_id, nil)
          if item_id.nil?
            next
          else
            volume_hash[item_id] += attributes.fetch(:working_volume).fetch(:qty)
          end
        end
      end
    end
    return volume_hash
  end
  
  def get_object_type_working_volume(container)
    working_volume = JSON.parse(container.object_type.data).fetch('working_vol', nil)
    raise "The #{container.id} #{container.object_type.name} ObjectType does not have a 'working_vol' association. 
    Please go to the container definitions page and add a JSON parsable association!".upcase if working_volume.nil?
    return working_volume.to_f
  end
  
  def get_transfer_volume_matrix(collection:, part_associations_matrix:, dilution_factor:)
    transfer_vol_matrix = Array.new(collection.object_type.rows) { Array.new(collection.object_type.columns) { EMPTY } }
    collection = collection_from(collection)
    collection_working_volume = get_object_type_working_volume(container=collection)
    collection.get_non_empty.each do |r, c|
      culture_volume = part_associations_matrix[r][c].fetch("Culture_Volume", false)
      if culture_volume
        transfer_vol_matrix[r][c] = (dilution_factor*collection_working_volume).round(3)
      end
    end
    return transfer_vol_matrix
  end
  
  def format_collection_display_str(value)
    if value.is_a? Hash
      return "#{(value[:qty]).round(3)}#{value[:units]}"
    elsif value.is_a? String
      return value
    else
      raise "This #{value.class} can not be formatted for collection display"
    end
  end

end #Class
```
