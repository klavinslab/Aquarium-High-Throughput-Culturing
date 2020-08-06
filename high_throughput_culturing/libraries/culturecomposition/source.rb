# By: Eriberto Lopez 
# elopez3@uw.edu
# Last Edit Checkpoint: 081419

needs "Standard Libs/Units"

# This class generates a data structure that describes multiple SampleTypes in order to represent an experimental microbial culture. 
# For each instance, it will calculate how much volume of each component is required to generate the desired culture composition.
# It then merges all components into a single data structure which represents the composition and the experimental intent of the user.
#
# @author Eriberto Lopez - elopez3@uw.edu
# @since 07/22/19
# 
# @param component_arr [array] is an array of hashes that comes from formatted 'Define Culture Conditions' FieldValues
# @param object_type [object] is the ObjectType of the container that will be used for culturing, this is necessary to calculate working volumes for all components in the culture.
# @param opts [hash] is a hash that is used for prototyping and adding addiitonal functionality without interupting core functions. Generally, not used.
# 
# @attr [hash] culture_volume is a hash that represents the total culture volume
# @attr [array of classes] components is an array of instatiated CultureComponent classes. Each with it's default volumes and items.
# @attr [hash] composition is a hash that represents a culture with multiple samples types or multiple combinations of similar sample types.
# @attr [hash] options is a hash that is used for prototyping and adding addiitonal functionality without interupting core functions. Generally, not used.
class CultureComposition
  
  attr_accessor :culture_volume, :components, :composition, :options
  
  def initialize(component_arr:, object_type:, opts: {})
    @components  = component_arr.map {|component| CultureComponent.new(component) }
    @culture_volume = get_container_properties(key: 'working_vol', object_type: object_type)
    @options     = opts
    update_culture_components_working_vol # Will calculate how much of each component is needed based on prev calc dilution factor
    @composition = generate_composition_data_structure
  end

  def get_component_attr(component)
    {
      component.sample.name => {
        item_id: component.item.id,
        item_concentration: component.stock_concentration,
        final_concentration: component.final_concentration,
        dilution_factor: component.dilution_factor,
        working_volume: component.working_vol
      }
    }
  end
  
  def generate_composition_data_structure
    data_structure = {}
    components.group_by {|c| c.input_name }.each do |input_name, components|
      components.each do |component|
        if data_structure.keys.include? input_name
          data_structure[input_name].merge!(get_component_attr(component))
        else
          data_structure[input_name] = get_component_attr(component)
        end
      end
    end
    data_structure["Option(s)"] = options
    data_structure["Culture_Volume"] = culture_volume
    return data_structure
  end

  def update_culture_components_working_vol
    components.each {|component| get_component_working_vol(component) }
    get_media_working_vol # After all of the additional components have been calculated, take the remainder vol and fill with media
  end
  
  def get_media_working_vol
    total_volume = culture_volume[:qty].to_f
    components.each {|component| total_volume -= component.working_vol.fetch(:qty).to_f }
    media_component = components.select {|c| c.input_name == "Media"}.first
    media_component.working_vol[:qty] = total_volume.round(3)
  end
  
  def get_component_working_vol(component)
    df = component.dilution_factor
    if !df.nil?
      component_working_vol_qty = culture_volume[:qty]*df
      component.working_vol = format_measurement(component_working_vol_qty, component.working_vol[:units])
    end
  end
  
  def format_measurement(qty, units)
    {qty: qty.to_f.round(2), units: units}
  end
  
  def get_container_properties(key:, object_type:)
    if object_type.data.include? key
      qty, units = JSON.parse(object_type.data)[key].split('_')
    else
      raise "The container that you are attempting to grow a culture in does not have a #{key} reference in it's container definition.
      Please update the #{object_type.name} object type definition!"
    end
    return format_measurement(qty, units)
  end
end # class CultureComposition

# This class instantiates a formatted culture component for the desired experimental condition. 
# A formatted hash object is used to instantiate this class to represent an experimental culture component. 
# A list of multiple CultureComponent instances is then used by the CultureComposition class, to build up the culture.composition data structure to represent an experimental culture.
#
# @author Eriberto Lopez - elopez3@uw.edu
# @since 07/22/19
#
# @param args [Hash] is a hash object with keys related to the attributes of this class
#
# @attr working_vol [Hash] object representing how much volume of a instantiated CultureComponent is required ie: {qty: 100, units: 'microliters'}
# @attr_reader  input_name [string] the name of the Aq sample describing the culture component
# @attr_reader  sample [Sample] the sample of the component
# @attr_reader  item [Item] the item from which the component is take from
# @attr_reader  stock_concentration [Hash] object representing the concentration of the item used in the culture {qty: 100, units: 'mM'}
# @attr_reader  final_concentration [Hash] object representing the desired final concentration of the component used in the culture {qty: 100, units: 'nM'}
# @attr_reader  dilution_factor [int] the computed amount of dilution required to dilute the stock_concentration to reach the desired final_concentration
# @attr_reader  added [boolean] a way to determine whether a component has been added to the culture
class CultureComponent
  include Units
  attr_accessor :working_vol
  attr_reader :input_name, :sample, :item, :stock_concentration, :final_concentration, :dilution_factor, :added
  
  def initialize(args={})
    @input_name = args.fetch(:input_name)
    @sample = args.fetch(:sample)
    @item = args.fetch(:item, nil)
    @final_concentration = args.fetch(:final_concentration, nil)
    @working_vol = { qty: 0, units: MICROLITERS }
    get_component_type_attributes#(args) May should add back args but dont think its needed
    @added = false
  end
  
  def get_component_type_attributes#(args) #May should add back args but dont think its needed
    case input_name
    when "Strain"
    when "Media"
    when "Control Tag"
    when "Inducer(s)"

      #if item.class == Hash then there is no stock.  Check here makes debugging easier
      if item.class == Hash 
        raise "Inducer not in stock, check all inducers for existing stock"
      end

      qty, units, name = item.object_type.name.split(' ')
      set_stock_item_concentration(qty: qty.to_f, units: units)
      set_dilution_factor(val: calculate_dilution_factor(stock_conc: stock_concentration, final_conc: final_concentration))
    when "Antibiotic(s)"
      @item = (item.nil?) ? (sample.items.select {|i| i.object_type.name == 'Antibiotic Aliquot'}.first) : item
      qty, units = sample.properties['Recommended Working Concentration (ug/mL)'], 'ug/mL' # Aliquots always have the same units
      set_stock_item_concentration(qty: qty.to_f, units: units)
      (final_concentration[:units] == units) ? (set_dilution_factor(val: final_concentration[:qty]/qty)) : (raise "The antibiotic units are not compatable in CultureComponent class")
    else 
      raise "#{input_name} is not a valid type of culture component. Please update class CultureComponent!"
    end
  end
  
  def set_stock_item_concentration(qty:, units:)
    units = (units == 'uM') ? MICROMOLAR : units
    @stock_concentration = { qty: qty.to_f, units: units }
  end
  
  def set_dilution_factor(val:)
    @dilution_factor = val
  end
  
  def calculate_dilution_factor(stock_conc:, final_conc:)
    stock_units = stock_conc[:qty]*CultureComponent.unit_conversion_hash[stock_conc[:units]]
    final_units = final_conc[:qty]*CultureComponent.unit_conversion_hash[final_conc[:units]]
    return (final_units/stock_units).round(4)
  end
  
  def self.unit_conversion_hash
    { NANOMOLAR => 10e-9, MICROMOLAR => 10e-6, 'uM' => 10e-6, MILLIMOLAR => 10e-3, MOLAR => 10e0 }
  end
end # CultureComponent


# Parses out JSON parameters & non-JSON parameters from the Define Culture Conditions operation.
module FieldValueParser
    
  def self.get_args_from(obj:)
    if obj.is_a? FieldValue
      case obj.name
      when "Strain", "Media"
        args_arr = FieldValueParser.get_non_parameter_args(fv: obj)
      when "Inducer(s)"
        args_arr = FieldValueParser.get_inducer_args(fv: obj)
        args_arr = FieldValueParser.generate_component_combinations(args_arr)
      when "Antibiotic(s)"
        args_arr = FieldValueParser.get_antibiotic_args(fv: obj)
      when "Option(s)"
        # Pass
      else
        raise "#{obj.name} is not a field value that can be parsed class."
      end
    else
      raise "#{obj.class} is not able to be used to initialize the CultureComposition class."
    end
    return args_arr
  end
  
  def self.get_antibiotic_args(fv:)
    args_arr = []
    JSON.parse(fv.value).each do |sname, opts|
      sample = Sample.find_by_name(sname)
      final_concentration = opts.fetch('final_concentration') 
      f_qty, f_units = final_concentration.split('_')
      args_arr.push({
        input_name: fv.name, 
        sample_name: sname,
        sample: sample,
        item: nil,
        final_concentration: {qty: f_qty.to_f, units: f_units}
      })
    end
    return args_arr
  end

  def self.get_non_parameter_args(fv:)
    {
      input_name: fv.name,
      sample_name: fv.sample.name,
      sample: fv.sample,
      item: fv.item
    }
  end
  
  def self.generate_component_combinations(args_arr)
    groupby_types = args_arr.group_by {|args| args.fetch(:sample_name) }
    num_of_components = groupby_types.keys.length
    if num_of_components > 1
      combinations = args_arr.combination(num_of_components).to_a.select {|combo| 
        combo.map {|args| args.fetch(:sample_name) }.uniq.length == num_of_components
      }
      return combinations
    else
      return (groupby_types.nil? ? groupby_types : groupby_types.values.first)
    end
  end
  
  def self.get_inducer_args(fv:)
    args_arr = []
    JSON.parse(fv.value).each do |sname, opts|
      sample = Sample.find_by_name(sname)
      final_concentration = opts.fetch('final_concentration')
      if final_concentration.is_a? Array
        sample_inventory = sample.items.reject {|item| item.location == 'deleted' }
        final_concentration.each_with_index do |fconc, idx|
          f_qty = fconc.split('_')[0].to_f; f_units = fconc.split('_')[1]
          item_id = opts.fetch('item_id', nil)
          if item_id.nil?
            item = FieldValueParser.get_inducer_component_item(sample: sample, sample_inventory: sample_inventory, fconc: fconc) 
          else
            item = (item_id.is_a? Array) ? Item.find(item_id[idx].to_i) : Item.find(item_id.to_i)
          end
          args_arr.push({
            input_name: fv.name, 
            sample_name: sname,
            sample: sample,
            item: item,
            final_concentration: {qty: f_qty, units: f_units}
          })
        end
      end
    end
    return args_arr
  end
  
  # This function helps Aq automatically find an inducer item when given the sample, the sample_inventory (all items that are not deleted), and the desired final_concentration
  # It selects the item by finding the dilution factor of the final_concentration divided by an item in the sample_inventory. If it is greater than a 0.001 fold dilution then it selects that item.
  # It must be greater than a 0.001 dilution in order to pipette accurately.
  def self.get_inducer_component_item(sample:, sample_inventory:, fconc:)
    inventory_by_object_type = sample_inventory.group_by {|item| item.object_type.name }
    f_qty = fconc.split('_')[0].to_f; f_units = fconc.split('_')[1]
    if f_qty <= 0.0
      item = sample_inventory.first
    else
      final_units = f_qty * CultureComponent.unit_conversion_hash[f_units] rescue (raise "#{sample.id} #{fconc}")
      inventory_by_object_type.each do |otname, item_arr|
        s_qty = otname.split(' ')[0].to_f; s_units = otname.split(' ')[1]
        stock_units = s_qty * CultureComponent.unit_conversion_hash[s_units]
        dilution_factor = (final_units/stock_units).round(4)
        if dilution_factor < 0.001
          next
        else
          return item_arr.first # return the lowest item_id or the oldest item
        end
        raise MissingInducerComponentItemError.new(sample: sample, final_concentration: fconc)
      end
    end
  end

  # Exception class for finding an inducer item that can be diluted accurately to reach the desired final concentration.
  #
  # @attr_reader [String] name  the name of the object type where measure has was expected TODO: Documentation
  class MissingInducerComponentItemError < StandardError
    attr_reader :sample_name, :final_concentration
    def initialize(msg: "A suitible inducer item cannot be found to reach the final concentration desired. Please add an object type to the inducer sample or add an item to its inventory", sample_name:, final_concentration:)
      @sample_name = sample_name
      @final_concentration = final_concentration
      super(msg)
    end
  end
  
end # module FieldValueParser

