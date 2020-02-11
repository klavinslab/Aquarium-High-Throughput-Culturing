# Dilute Collection

This protocol will guide you on how to dilute the cultures of a culturing plate into another plate.

    1. Gather materials.
    
    2. Pre-fill new plate with media, if necessary.
    
    3. Transfer aliquot of culture to new plate.
    
    4. Incubate.


This operation takes in a collection and dilutes the microbial cultures found in it by a user specified dilution factor. It requires that the output container have a `Data` association {'working_vol': '1000_uL'} in order for the dilution to be computed.
### Inputs


- **Culture Plate** [P] (Array) 
  - NO SAMPLE TYPE / <a href='#' onclick='easy_select("Containers", "Eppendorf 96 Deepwell Plate")'>Eppendorf 96 Deepwell Plate</a>
  - NO SAMPLE TYPE / <a href='#' onclick='easy_select("Containers", "96 Well Flat Bottom (black)")'>96 Well Flat Bottom (black)</a>
  - NO SAMPLE TYPE / <a href='#' onclick='easy_select("Containers", "96 U-bottom Well Plate")'>96 U-bottom Well Plate</a>
  - NO SAMPLE TYPE / <a href='#' onclick='easy_select("Containers", "24 Unit Disorganized Collection")'>24 Unit Disorganized Collection</a>

- **Media** [M]  
  - <a href='#' onclick='easy_select("Sample Types", "Media")'>Media</a> / <a href='#' onclick='easy_select("Containers", "800 mL Liquid")'>800 mL Liquid</a>

### Parameters

- **Dilution** [0.5X, 0.2X,0.1X, 0.01X,0.001X]
- **Keep Input Plate?** [Yes,No]

### Outputs


- **Diluted Plate** [P] (Array) 
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
# 08/13/19

needs "Standard Libs/Debug"
needs "High Throughput Culturing/HighThroughputHelper"

class Protocol
  include HighThroughputHelper
  include Debug
  
  # DEF
  INPUT = "Culture Plate"
  OUTPUT = "Diluted Plate"
  DILUTION = "Dilution"
  MEDIA = "Media"
  KEEP_IN_PLT = "Keep Input Plate?"
  
  # Constants
  ALLOWABLE_DILUTANT_SAMPLETYPES = ['Yeast Strain', 'Plasmid', 'E coli strain'] # sample types that will be transferred to new plate
  
  # Access class variables via Protocol.your_class_method
  @materials_list = []
  def self.materials_list; @materials_list; end
  
  def intro
    show do
      title "Dilute Collection"
      separator
      note "This protocol will guide you on how to dilute the cultures of a culturing plate into another plate."
      note "<b>1.</b> Gather materials."
      note "<b>2.</b> Pre-fill new plate with media, if necessary."
      note "<b>3.</b> Transfer aliquot of culture to new plate."
      note "<b>4.</b> Incubate."
    end
  end
  
  def main
    intro
    operations.retrieve.make
    clean_up_arr = []
    operations.make.each do |op|
      dilution_factor = get_dilution_factor(op: op, fv_str: DILUTION)
      op.input_array(INPUT).collections.zip(op.output_array(OUTPUT).collections) do |from_collection, to_collection|
        raise "Not enough output plates have been planned please add an output field value to this operation: Plan #{op.plan.id} Operation #{op.id}." if to_collection.nil? 
        gather_materials(empty_containers: [to_collection], new_materials: ['P1000 Multichannel', 'Permeable Area Seals', 'Multichannel Resivior'], take_items: [from_collection] )
        stamp_transfer(from_collection: from_collection, to_collection: to_collection, process_name: 'dilution')
        transfer_volume = pre_fill_collection(to_collection: to_collection, dilution_factor: dilution_factor, media_item: op.input(MEDIA).item)
        tech_transfer_samples(from_collection: from_collection, to_collection: to_collection, transfer_volume: transfer_volume)
        from_loc = from_collection.location; to_collection.location = from_loc; to_collection.save()
        (op.input(KEEP_IN_PLT).val.to_s.downcase == 'yes') ? (from_collection.mark_as_deleted; from_collection.save()) : nil
      end
      clean_up(item_arr: clean_up_arr)
      operations.store
    end
  end #main
  
  def tech_transfer_samples(from_collection:, to_collection:, transfer_volume:)
    show do
      title "Transferring From #{from_collection} To #{to_collection}"
      separator
      warning "Make sure that both plates are in the same orientation.".upcase
      note "Using a Multichannel pipette, follow the table to transfer #{transfer_volume}#{MICROLITERS} of cultures:"
      bullet "<b>From #{from_collection.object_type.name}</b> #{from_collection}"
      bullet "<b>To #{to_collection.object_type.name}</b> #{to_collection}"
      table highlight_alpha_non_empty(to_collection) {|r,c| "#{transfer_volume}#{MICROLITERS}" }
    end
  end

  def pre_fill_collection(to_collection:, dilution_factor:, media_item:)
    destination_working_volume = get_object_type_working_volume(to_collection).to_i
    culture_volume = (destination_working_volume*dilution_factor.to_i).round(3)
    media_volume = (destination_working_volume-culture_volume).round(3)
    take [media_item], interactive: true
    if dilution_factor != 'None'
      total_media = ((to_collection.get_non_empty.length*media_volume*1.1)/1000).round(2) #mLs
      show do 
        title "Pre-fill #{to_collection.object_type.name} #{to_collection} with #{media_item.sample.name}"
        separator
        check "Gather a <b>Multichannel Pipette<b>"
        check "Gather a <b>Multichannel Resivior<b>"
        check "Gather #{total_media}#{MILLILITERS}"
        note "Pour the media into the resivior in 30mL aliquots"
        note "You will need these materials in the next step."
      end
      show do
        title "Pre-fill #{to_collection.object_type.name} #{to_collection} with #{media_item.sample.name}"
        separator
        note "Follow the table below to transfer media into #{to_collection}:"
        table highlight_alpha_non_empty(to_collection){|r,c| "#{media_volume}#{MICROLITERS}"}
      end
    end
    return culture_volume
  end

  def get_object_type_working_volume(container)
    working_volume = JSON.parse(container.object_type.data).fetch('working_vol', nil)
    raise "The #{container.id} #{container.object_type.name} ObjectType does not have a 'working_vol' association. 
    Please go to the container definitions page and add a JSON parsable association!".upcase if working_volume.nil?
    return working_volume
  end
  
  def copy_sample_matrix(from_collection:, to_collection:)
    sample_hash = Hash.new()
    from_collection_sample_types = from_collection.matrix.flatten.uniq.reject{|i| i == EMPTY }.map {|sample_id| [sample_id, Sample.find(sample_id)] }
    from_collection_sample_types.each {|sid, sample| (ALLOWABLE_DILUTANT_SAMPLETYPES.include? sample.sample_type.name) ? (sample_hash[sid] = sample) : (sample_hash[sid] = EMPTY) }
    dilution_sample_matrix = from_collection.matrix.map {|row| row.map {|sample_id| sample_hash[sample_id] } }
    to_collection.matrix = dilution_sample_matrix
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
    # Set edited map to the destination collection_associations
    to_collection_associations.instance_variable_set(:@map, from_associations_map)
    to_collection_associations.save()
    return from_associations_map
  end    
    
  def part_provenance_transfer(from_collection:, to_collection:, process_name:)
    to_collection_part_matrix = to_collection.part_matrix
    from_collection.part_matrix.each_with_index do |row, r_i|
      row.each_with_index do |from_part, c_i|
        if (from_part) && (ALLOWABLE_DILUTANT_SAMPLETYPES.include? from_part.sample.sample_type.name)
          to_part = to_collection_part_matrix[r_i][c_i]
          if !to_part.nil?
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
  end
  
  def stamp_transfer(from_collection:, to_collection:, process_name: nil)
    from_associations_map = transfer_part_associations(from_collection: from_collection, to_collection: to_collection)
    part_provenance_transfer(from_collection: from_collection, to_collection: to_collection, process_name: process_name)
    return from_associations_map.fetch('part_data')
  end

end #Class

```
