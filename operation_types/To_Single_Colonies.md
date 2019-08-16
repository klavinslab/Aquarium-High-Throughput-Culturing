# To Single Colonies

This protocol will guide you in streaking out cells onto an agar plate in order to generated isolated colonies.
### Inputs


- **Yeast Inoculum** [C]  
  - <a href='#' onclick='easy_select("Sample Types", "Yeast Strain")'>Yeast Strain</a> / <a href='#' onclick='easy_select("Containers", "Yeast Glycerol Stock")'>Yeast Glycerol Stock</a>
  - <a href='#' onclick='easy_select("Sample Types", "Yeast Strain")'>Yeast Strain</a> / <a href='#' onclick='easy_select("Containers", "Yeast Overnight Suspension")'>Yeast Overnight Suspension</a>

### Parameters

- **Media** [YPAD,SC,SDO,SDO -His,SDO -Leu,SDO -Trp,SDO -Ura,SDO -His -Leu,SDO -His -Trp,SDO -His -Ura,SDO -Leu -Trp,SDO -Leu -Ura,SDO -Trp -Ura,SDO -His -Leu -Trp,SDO -His -Leu -Ura,SDO -His -Trp -Ura,SDO -Leu -Trp -Ura]

### Outputs


- **Plate** [C]  
  - <a href='#' onclick='easy_select("Sample Types", "Yeast Strain")'>Yeast Strain</a> / <a href='#' onclick='easy_select("Containers", "Yeast Plate")'>Yeast Plate</a>

### Precondition <a href='#' id='precondition'>[hide]</a>
```ruby
def precondition(_op)
  true
end
```

### Protocol Code <a href='#' id='protocol'>[hide]</a>
```ruby
# By: Eriberto Lopez 01/22/18
# elopez3@uw.edu

needs "Standard Libs/Debug" 

class Protocol
  include Debug
  
  # DEF
  INPUT = "Yeast Inoculum"
  OUTPUT = "Plate"
  MEDIA = "Media"
  
    
  def main
    intro
    get_plates
    operations.make
    # Grab materials and label plates
    gly_stks, cultures = gather_materials
    streak_plates(gly_stks, cultures)
    # Move new plates to incubator
    plates = operations.running.map { |op| op.output(OUTPUT).item.move "30C incubator" }
    release(plates, interactive: true)
    if cultures.empty? == false then discard_cultures(cultures) end
    return {}
  end # Main
  
  # Make a list of all the operations with each unique plate type
  def get_media_types()
    operations.map {|op| op.input(MEDIA).val.to_str }.uniq
  end
  
  def check_media_type_plate_inventory()
    ##The following block will error out any operations for which we don't actually have plates available. 
    groupby_media_type = operations.group_by {|op| op.input(MEDIA).val.to_str }
    groupby_media_type.each do |mt, media_ops|
      media_sample = Sample.find_by_name(mt)
      plates_needed = media_ops.length
      batches = Collection.where(object_type_id: ObjectType.find_by_name("Agar Plate Batch").id).select {|b| b.matrix.first.include? media_sample.id } #Find the plate batches
      #Check how many plates of this media type we actually have available, and see how that relates to the number of plates we need. 
      plates_available = 0; batches.each {|b| plates_available = plates_available + b.num_samples }
      difference = plates_needed - plates_available
      # If we have a shortfall o plates we need to error out that number of operations. 
      if difference > 0
        ops_to_error = media_ops[0..difference]
        ops_to_error.each do |op|
          op.error :plate_needed, "Not enough agar plates of the required media type available - #{op.input(MEDIA).val.to_str}"
        end
        #A little note so the technicians understand why there are now fewer operations running
        show do 
          title "More plates required"
          note "#{difference} operations have been errored because there are not enough plates of the type #{media_sample.name}"
        end
      end
    end
  end
  
  def get_plates
    ##The following block will error out any operations for which we don't actually have plates available. 
    check_media_type_plate_inventory
    ##Having errored out some operations we need to again check how many plates we're now looking for and send the technician to go get them. 
    ##So we're going to update our variables to reflect the fact that we errored out some operations. 
    groupby_media_type = operations.running.group_by {|op| Sample.find_by_name(op.input(MEDIA).val.to_s) }
    groupby_media_type.each do |media_sample, media_ops|
      plates_needed = media_ops.length #How many plates do we need of this media type?
      batches = Collection.where(object_type_id: ObjectType.find_by_name("Agar Plate Batch").id).select { |b| b.matrix.first.include? media_sample.id } #Find the plate batches
      # Work out which batches we need to take the plates from and update the inventory to reflect the removed plates. 
      # We're also going to keep track of all batches that will be touched to be able to instruct the technicians. 
      # This is consdering that we may need to take all plates from one batch and then also a few more from another batch. 
      batch_ids = []
      plates_needed.times do 
        batch_id = batches.first.id
        batch_ids.push(batch_id.to_s)
        batches.first.remove_one media_sample
        batches = Collection.where(object_type_id: ObjectType.find_by_name("Agar Plate Batch").id).select { |b| b.matrix[0].include? media_sample.id }
      end
      unique_batch_ids = batch_ids.uniq
      #Finally we can instruct the technician to get the plates. 
      show do 
        title "Retrieve #{media_sample.name} plates"
        check "From the media fridge retrieve #{plates_needed} plates from the tupperware container labeled: #{media_sample.name}, #{unique_batch_ids}"
      end
    end
  end
  
  def intro()
    container = operations.running.map {|op| op.input(INPUT).object_type.name}.uniq
    img = "Actions/Yeast_Gates/t_streak_method.png" #ie: image "Actions/FlowCytometry/saveFCS_menu_cropped.png"
    show do 
      title "Introduction"
      separator
        if container.length == 1
          note "In this protocol you will isolate single colonies from a #{container.first} using the T-streak technique."
        elsif container.length >1
          note "In this protocol you will isolate single colonies from the object types: #{container} using the T-streak technique."
        end
      image img
    end
  end
  
  def gather_materials()
    groupby_input_object_type = operations.running.group_by {|op| op.input(INPUT).item.object_type.name }
    gly_stks = groupby_input_object_type.fetch("Yeast Glycerol Stock", []).map {|op|  op.input(INPUT).item }
    cultures = groupby_input_object_type.fetch("Yeast Overnight suspension", []).map {|op|  op.input(INPUT).item }
    plate_ids = operations.running.map {|op| op.output(OUTPUT).item.id }
    show do
      title "Materials for Plate Streaking"
      separator
      check "Box of P1000 tips."
      check "Box of P100 tips and P100 pipette"
      check "Sharpie Pen"
      check "Label plate(s): <b> #{plate_ids}</b>"
    end
    return gly_stks, cultures, plate_ids
  end
  
  def streak_plates(gly_stks, cultures)
    img1 = "Actions/Yeast_Gates/initial_innoculation_new.png"
    img2 = "Actions/Yeast_Gates/second_streak_new.png"
    img3 = "Actions/Yeast_Gates/third_streak_incubation_new.png"
    show do
      title "Inoculation from glycerol stock in M80 area"
      separator
      check "Go to M80 area, clean out the pipette tip waste box, clean and sanatize area."
      check "Put on new gloves, and bring a new tip box (blue: 100 - 1000 uL) and an Eppendorf tube rack to the M80 area."
      check "Grab the plates and go to M80 area to perform inoculation steps in the next pages."
      image "Actions/Streak Plates/streak_yeast_plate_setup.JPG"
    end
    # Sorting glycerol stocks by box and location
    gly_stks.sort! {|x, y| x.location.split('.')[1..3] <=> y.location.split('.')[1..3]} # Sorts by the box number Fridge.X.X.X
    items_grouped_by_box = gly_stks.group_by {|i| i.location.split('.')[1]}
    items_grouped_by_box.each {|box_num, item_arr| # Groups by box then takes by box location
      take item_arr, interactive: true, method: "boxes"
    }
    (!cultures.nil?) ? (take cultures, interactive: true) : (nil)
    show do 
      title "Streak Out on Plate"
      separator
      note "Streak out the initial innoculation as shown in the example below - a slightly bigger patch is better."
      if cultures.empty? == false
          note "<b>For liquid cultures</b> use a pipette to drop 10 µl onto the plate as the initial inoculum"
      end
      image img1
      note "Streak out the Yeast Glycerol Stock on the plate(s) according to the following table: "
      table operations.start_table
        .input_item(INPUT, heading: "Yeast stock/culture ID")
        .output_item(OUTPUT, heading: "Yeast Plate ID", checkable: true)
      .end_table
      note "Continue on the the next steps to isolate single colonies."
    end
    release(gly_stks,interactive: true)
    show do
      title "Isolating Single Colonies"
      separator
      note "Next, with a new P1000 pipette tip streak out from the initial patch made."
      note "Use the image as an example."
      image img2
      note "Repeat this once more with a clean P1000 tip."
      image img3
    end
  end
  
  def discard_cultures(cultures)
    show do
      title "Discard overnight suspensions"
      note "Place the following tubes in the cleaning rack by the sink to be bleached and disposed of"
      cultures.each do |on|
          check "#{on.id}"
        end
     end
    cultures.each do |on|
      on.mark_as_deleted
      on.save
     end
  end
end # Class

```
