# Inoculate Culture Plate

This protocol, organizes a culturing experiment into a high throughput container.
The culturing could be very complex with additional inducers and reagents required to test experimental conditions.

    1. Gather materials for experiment.
    
    2. Fill and inoculate the container.
    
    3. Place plate in growth environment.
### Inputs


- **Culture Condition** [CC] (Array) 
  - <a href='#' onclick='easy_select("Sample Types", "Yeast Strain")'>Yeast Strain</a> / <a href='#' onclick='easy_select("Containers", "Yeast Plate")'>Yeast Plate</a>
  - <a href='#' onclick='easy_select("Sample Types", "Yeast Strain")'>Yeast Strain</a> / <a href='#' onclick='easy_select("Containers", "Yeast Glycerol Stock")'>Yeast Glycerol Stock</a>
  - <a href='#' onclick='easy_select("Sample Types", "Plasmid")'>Plasmid</a> / <a href='#' onclick='easy_select("Containers", "E coli Plate of Plasmid")'>E coli Plate of Plasmid</a>
  - <a href='#' onclick='easy_select("Sample Types", "E coli strain")'>E coli strain</a> / <a href='#' onclick='easy_select("Containers", "E coli Glycerol Stock")'>E coli Glycerol Stock</a>
  - <a href='#' onclick='easy_select("Sample Types", "Yeast Strain")'>Yeast Strain</a> / <a href='#' onclick='easy_select("Containers", "Yeast Overnight Suspension")'>Yeast Overnight Suspension</a>

### Parameters

- **Option(s)** 
- **Temperature (°C)** 

### Outputs


- **Culture Plate** [P] (Array) 
  - NO SAMPLE TYPE / <a href='#' onclick='easy_select("Containers", "Eppendorf 96 Deepwell Plate")'>Eppendorf 96 Deepwell Plate</a>
  - NO SAMPLE TYPE / <a href='#' onclick='easy_select("Containers", "24 Unit Disorganized Collection")'>24 Unit Disorganized Collection</a>

### Precondition <a href='#' id='precondition'>[hide]</a>
```ruby
# use the precondition to determine how many output fv need to be planned in the output array of this operation. 
# This precondition could be used to ensure that the user has planned enough output collections
def precondition(_op)
  true
end

```

### Protocol Code <a href='#' id='protocol'>[hide]</a>
```ruby
# By: Eriberto Lopez
# elopez3@uw.edu
# 06/26/19

needs "Standard Libs/Debug"
needs "High Throughput Culturing/CultureComposition"
needs "High Throughput Culturing/HighThroughputHelper"

class Protocol
  include Debug
  include HighThroughputHelper
  
  # DEF
  INPUT = "Culture Condition"
  OUTPUT = "Culture Plate"
  TEMPERATURE = "Temperature (°C)"
  
  # Predcessor DEF
  STRAIN = "Strain"
  MEDIA = "Media"
  INDUCERS = "Inducer(s)"
  ANTIBIOTICS = "Antibiotic(s)"
  CONTROL = "Control Tag"
  REPLICATES = "Replicates"
  OPTIONS = "Option(s)"

  # Access class variables via Protocol.your_class_method
  @materials_list = []
  def self.materials_list; @materials_list; end
  
  def intro
    show do
      title "High Throughput Culturing"
      separator
      note "This protocol, organizes a culturing experiment into a high throughput container."
      note "The culturing could be very complex with additional inducers and reagents required to test experimental conditions."
      note "<b>1.</b> Gather materials for experiment."
      note "<b>2.</b> Fill and inoculate the container."
      note "<b>3.</b> Place plate in growth environment."
    end
  end
  
  def main
    intro
    clean_up_arr = []
    operations.group_by {|op| get_uninitialized_output_object_type(op) }.map do |out_ot, ops|
      ops.map do |op|
        op = Operation.find(219536) if debug
        experimental_cultures = []; control_cultures = []
        condition_ops = get_define_culuture_condition_ops(op) # Predecessor operations
        condition_ops.map do |condition_op|
          control_tag           = get_control_tag(condition_op)
          replicate_num         = get_replicate_num(condition_op)
          condition_options     = get_condition_options(condition_op)
          culture_component_arr = get_base_culture_components(condition_op)
          # Format inducer components to account for combintorial inducer conditions, prior to initializing CultureComposition
          formatted_inducer_components = format_induction_components(condition_op)
          # Arrange component array by combining the culture component arr with the varying inducer components, unless we do not need inducers
          distribute_inducer_components(culture_component_arr: culture_component_arr, formatted_inducer_components: formatted_inducer_components).each do |component_arr|
            culture = CultureComposition.new(component_arr: component_arr, object_type: out_ot, opts: condition_options)
            culture.composition.merge!(control_tag)
            culture.composition.merge!(get_source_item_input(culture))
            replicates = replicate_culture(culture: culture, replicate_num: replicate_num) 
            (control_tag.fetch('Control').empty?) ? experimental_cultures.push(replicates) : control_cultures.push(replicates)
          end
        end
        # Place sorted cultures into new collection & set the new collections to the ouput array of the operation
        new_output_collections = associate_cultures_to_collection(cultures: experimental_cultures, object_type: out_ot)
        output_array = op.output_array(OUTPUT)
        new_output_collections.each_with_index do |out_collection, idx|
          associate_controls_to_collection(cultures: control_cultures, collection: out_collection)
          if output_array[idx].nil? # If there are no output field values left to fill create a new one and add it to the output array
            new_fv = create_new_fv(args=get_fv_properties(output_array[idx-1]))
            output_array.push(new_fv)
          end
          output_array[idx].set collection: out_collection
        end
        # Depending on the type of input items prepare inoculates using the inoculation_prep_hash
        inoculation_prep_hash = get_inoculation_prep_hash(new_output_collections)
        inoculate_culture_plates(new_output_collections: new_output_collections, inoculation_prep_hash: inoculation_prep_hash)
        incubate_plates(output_collections: new_output_collections, growth_temp: op.input(TEMPERATURE).val)
      end
    end
    clean_up(item_arr: clean_up_arr.flatten.uniq)
    { operations: operations.map {|op| op } }
  end # Main
  
  # Based on the user defined number of replicates, create an array of culture composition hash objects
  #
  # @params culture [class CultureComposition] is an instance of the CultureComposition class that represents a microbial culture with intended experimental conditions
  # @params replicate_num [int] the number of replicates for this culture experimental condition
  # @returns [Array] an array of hash objects representing exprimental culture replicates
  def replicate_culture(culture:, replicate_num:)
    return replicate_num.times.map {|i| culture.composition.merge({'Replicate'=>"#{i+1}/#{replicate_num}"}) }
  end  
  
  # Find the inoculum item of a culture
  #
  # @params culture [class CultureComposition] is an instance of the CultureComposition class that represents a microbial culture with intended experimental conditions
  # @returns [hash] source array hash object
  def get_source_item_input(culture)
    source_array = []
    source_array.push({id: culture.composition.fetch(STRAIN).values.first[:item_id]})
    return { 'source'=> source_array }
  end
  
  # Create an array of predessor operations that are wired to the input array of this Inoculate Culture Plate operation
  def get_define_culuture_condition_ops(op)
    predecessor_output_fv_ids = op.input_array(INPUT).map {|fv| fv.wires_as_dest.first.from_id } # Finding the pred fv ids by using the wires connecting them to this op.input_array
    define_culture_condition_ops = FieldValue.find(predecessor_output_fv_ids).to_a.map {|fv| fv.operation } # Predecessor operations
    return define_culture_condition_ops
  end
  
  # Get predessor operation input OPTIONS
  def get_condition_options(condition_op)
    condition_op.input(OPTIONS).val
  end
  
  # Get predessor operation input REPLICATES
  def get_replicate_num(condition_op)
    condition_op.input(REPLICATES).val.to_i
  end
  
  # Get predessor operation input CONTROL
  def get_control_tag(condition_op)
    { 'Control' => condition_op.input(CONTROL).val }
  end
  
  # Get predessor operation input STRAIN, MEDIA, ANTIBIOTICS
  def get_base_culture_components(condition_op)
    base_component_fvs = condition_op.field_values.select {|fv| ([STRAIN, MEDIA, ANTIBIOTICS].include? fv.name) && (fv.role == 'input') }
    culture_component_arr = base_component_fvs.map {|fv| FieldValueParser.get_args_from(obj: fv) }.flatten.reject {|component| component.empty? }
    return culture_component_arr
  end
  
  # Uses class methods from module FieldValueParser to parse out inducer combination JSON parameters
  def format_induction_components(condition_op)
    inducer_fv = get_inducer_fieldValue(condition_op)
    formatted_inducer_components = FieldValueParser.get_args_from(obj: inducer_fv)
  end
  
  # Get predessor operation input INDUCERS
  def get_inducer_fieldValue(condition_op)
    condition_op.field_values.select {|fv| fv.name == INDUCERS }.first
  end
  
  # Generate inducer component objects to create the combinatorial induction conditions for multiplexed(2 or more) inducers
  def induction_culture_component_generator(formatted_inducer_components, &block)
    formatted_inducer_components.each {|inducer_component| yield inducer_component } 
  end
  
  # Create an array of culture condition objects, to instatiate class CultureComposition. Generate an array, with base culture conditions, for each formatted inducer combination.
  #
  # @params culture_component_arr [Array] array of hash objects each representing a component of a experimental microbial culture
  # @params formatted_inducer_components [Array] array of hash objects each representing an inducer component. An inducer component can be comprised of more than one inducer.
  # @returns culture_condition_arr [2-D Array] an array of arrays. The rows in this matrix represent experimental cultures, these arrays are used to instantiate class CultureComposition
  def distribute_inducer_components(culture_component_arr:, formatted_inducer_components:)
    culture_condition_arr = []
    if formatted_inducer_components
      induction_culture_component_generator(formatted_inducer_components) {|inducer_component| culture_condition_arr.push(culture_component_arr.dup.push(inducer_component).flatten) }
    else
      culture_condition_arr.push(culture_component_arr.dup)
    end
    return culture_condition_arr
  end
  
  # Copy the properties of a given field value. This is used to generate and plan more output FieldValues if not enough output culture plates are planned.
  #
  # @params fv [FieldValue] the input or output of an operation. The green or orange bubbles seen in the designer GUI.
  def get_fv_properties(fv)
    {
      name: fv.name,
      role: fv.role,
      field_type_id: fv.field_type_id,
      allowable_field_type_id: fv.allowable_field_type_id,
      parent_class: fv.parent_class,
      parent_id: fv.parent_id
    }
  end
  
  # Instantiate a new FieldValue
  # 
  # @params args [Hash] hash object with FieldValue properties needed to duplicate a FieldValue
  def create_new_fv(args={})
    fv = FieldValue.new()
    (args) ? set_fv_properties(fv, args) : nil
    fv.save()
    return fv
  end
  
  # Set the properties of a FieldValue from a hash object
  def set_fv_properties(fv, args={})
    args.each {|k,v| fv[k] = v }
    fv.save()
    return fv
  end
  
end # Protocol
```
