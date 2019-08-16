# frozen_string_literal: true

# Module with methods and classes that seek to help with associating data
# to, and retrieving data from, items, operations, plans, collections, and parts.
#
module AssociationManagement
  require 'matrix'

  # Associates a key and value to the associations hash of the given object.
  # Replaces an existing association for the given key.
  #
  # A part may be represented as a part item, or a collection and coordinate.
  #
  # @param object [DataAssociator]  the object to associate data
  # @param key [String]  the key for the association
  # @param data [serializable object]  the data for the association
  # @param opts [Hash]  additional method options
  # @option coord [Array]  row, column pair if the object is a collection
  # @option data_matrix [String]  optional data matrix for a collection
  def associate_data(object, key, data, opts = {})
    AssociationMap.associate_data(object, key, data, opts)
  end

  # Returns the associated value from the associations hash of a given object.
  # If an association doesn't exist for the key, returns nil.
  #
  # @param object [DataAssociator]  the object to associated data
  # @param key [String]  the key for the association
  # @param opts [Hash]  additional method options
  # @option coord [tuple Array]  row, column of part if object is a collection.
  # @option data_matrix [String]  optional data matrix
  # @return [serializable object]  the value associated with the given key
  def get_associated_data(object, key, opts = {})
    AssociationMap.get_associated_data(object, key, opts)
  end

  # Defines a map to manage the associations for an {Item}, {Operation}, or
  # {Plan} object, which are Aquarium classes that extend {DataAssociator}.
  #
  # Note: if `map` contains associations, it is necessary to call `map.save` for
  #       the associations to be saved to Aquarium.
  #
  class AssociationMap
    DATAMATRIX_KEY = 'part_data'

    # Initializes an {AssociationMap} for the given item, operation, or plan.
    #
    # @param object [DataAssociator]  the object to which to associated data
    def initialize(object)
      @object = object
      @map = {}

      @object.associations.each do |datum|
        @map[datum[0]] =
          if @object.upload(datum[0]).nil?
            datum[1]
          else
            UploadAssoc.new(datum[1], @object.upload(datum[0]))
          end
      end

      if object.is_a? Collection
        initialize_part_data
        data_matrix_all(@object, @map[DATAMATRIX_KEY])
      end
    end

    # Retrieves part_data from the data associations of constituent parts.
    # achieves forward compatibility with AQ Part update
    def data_matrix_all(coll, data_matrix)
      pas = coll.part_associations
      part_ids = pas.collect(&:part_id)
      das = DataAssociation.where(parent_class: 'Item', parent_id: part_ids)
      pas.each do |pa|
        data_matrix[pa.row][pa.column] = {}
        das.select { |da| da.parent_id == pa.part_id }.each do |da|
          data_matrix[pa.row][pa.column][da.key] = da.value
        end
      end
      data_matrix
    end

    # All in one static method which associates a key and value
    # to the associations hash of a given object. If an association already
    # exists at the given key, it will be replaced. Can associate to parts of collection either
    # using a part field value, or an optional coordinate specification with a collection
    #
    # @param object [DataAssociator]  the object to which data is to be associated. Can be an io field value
    # @param key [String]  the key for the association
    # @param data [serializable object]  the data for the association
    # @param opts [Hash]  additional method options
    # @option coord [tuple Array]  specify r, c index of the data matrix of the object to upload to,
    #                   rather than directly to the object. Requires that object is a collection.
    # @option data_matrix [String]  optionally, when associating to a part of a collection, use a
    #                         data matrix besides the default one
    def self.associate_data(object, key, data, opts = {})
      defaults = { data_matrix: DATAMATRIX_KEY }
      opts.merge defaults
      raise 'Bad Arguments: cannot associate to a part and specify coords at the same time' if object.is_a?(FieldValue) && opts[:coord]
      if object.is_a?(FieldValue)
        assoc_map = AssociationMap.new(object.collection)
        assoc_map.putrc(object.row, object.column, key, data)
      elsif opts[:coord]
        assoc_map = AssociationMap.new(object)
        assoc_map.putrc(opts[:coord][0], opts[:coord][1], key, data)
      else # Normal case that deals directly with object
        assoc_map = AssociationMap.new(object)
        assoc_map.put(key, data)
      end
      assoc_map.save
    end

    # All in one static method which gets an associated value
    # from the associations hash of a given object. If an association doesn't
    # exist at the given key, returns nil. Can get associations from parts of collection either
    # using a part field value, or an optional coordinate specification with a collection
    #
    # @param object [DataAssociator]  the object to which data is to be associated, can be an io field value
    # @param key [String]  the key for the association
    # @param opts [Hash]  additional method options
    # @option coord [tuple Array]  specify r, c index of the data matrix of the object to upload to,
    #                   rather than directly to the object. Requires that object is a collection.
    # @option data_matrix [String]  optionally, when retrieving association from a part of a collection,
    #                         use a matrix besides the default one
    # @return [serializable object]  the data stored in the associations of the given object at the given key
    def self.get_associated_data(object, key, opts = {})
      defaults = { data_matrix: DATAMATRIX_KEY }
      opts.merge defaults
      raise 'Bad Arguments: cannot get data from a part and specify coords at the same time' if object.is_a?(FieldValue) && opts[:coord]
      if object.is_a?(FieldValue)
        assoc_map = AssociationMap.new(object.collection)
        return assoc_map.getrc(object.row, object.column, key)
      elsif opts[:coord]
        assoc_map = AssociationMap.new(object)
        return assoc_map.getrc(opts[:coord][0], opts[:coord][1], key)
      else # Normal case that deals directly with object
        assoc_map = AssociationMap.new(object)
        return assoc_map.get(key)
      end
    end

    # Adds an association for the data with the key.
    # The data must be serializable.
    #
    # @param key [String]  the key for the association
    # @param data [serializable object]  the data for the association
    # @param opts [Hash]  Additional Options
    # @option tag  [String]  If putting an Upload, optionally specify an extra label
    def put(key, data, opts = { tag: {} })
      @map[key] = if data.is_a?(Upload)
                    UploadAssoc.new(opts[:tag], data)
                  else
                    data
                  end
    end

    # Adds an association for the data with the key, for
    # a specific row, column coordinate within a collection
    # If the data_matrix for the collection has not been created yet, it is initialized
    #
    # @requires  current object is a Collection, and r,c corresponds to a valid location in the object
    # @param r [Integer]  the row of the part within the collection to associate to
    # @param c [Integer]  the column of the part within the collection to associate to
    # @param key [String]  the key for the association
    # @param data [serializable object]  the data for the association
    # @param data_matrix [String/Symbol]  optionally specify a data matrix to access besides the default one,
    #                         for example, you might have the default part data, alongside a routing matrix
    def putrc(row, column, key, data, data_matrix = DATAMATRIX_KEY)
      # if the data_matrix for this collection does not exist yet, initialize it.
      initialize_part_data(data_matrix)
      @map[data_matrix][row][column][key] = data
    end

    # To be called when the object of association is a collection,
    # establishes a matrix parallel to the sample matrix which can
    # be used to store additional information about individual parts
    # Each slot in the matrix will be a new empty hash.
    #
    # @param coll [Collection]  the object for which part-data matrix will be initialized
    # @param data_matrix [String/Symbol]  optionally specify a data matrix to access besides the default one,
    #                         for example, you might have the default part data, alongside a routing matrix
    def initialize_part_data(data_matrix = DATAMATRIX_KEY)
      raise "Invalid Method Call: cannot associate part data to an object that isn't a collection" unless @object.is_a?(Collection)
      coll = collection_from(@object.id)
      @map[data_matrix] = Array.new(coll.dimensions[0]) { Array.new(coll.dimensions[1]) { {} } } if @map[data_matrix].nil?
    end

    # Returns the associated data for the key, if any.
    #
    # @param key [String]  the key for the association
    # @returns the data object for the key, `nil` otherwise
    def get(key)
      data = @map[key]
      if data.is_a?(UploadAssoc)
        data.upload
      else
        data
      end
    end

    # Gets an association for the data with the key, for
    # a specific row, column coordinate within a collection
    # Returns the associated data for the key, if any.
    #
    # @requires  current object is a Collection, and r,c corresponds to a valid location in the object
    # @param r [Integer]  the row of the part within the collection to associate to
    # @param c [Integer]  the column of the part within the collection to associate to
    # @param key [String]  the key for the association
    # @param data_matrix [String/Symbol]  optionally specify a data matrix to access besides the default one,
    #                         for example, you might have the default part data, alongside a routing matrix
    # @returns the data object for the key, `nil` otherwise
    def getrc(row, column, key, data_matrix = DATAMATRIX_KEY)
      @map[data_matrix][row][column][key] unless @map[data_matrix].nil?
    end

    # Retrieve the associations for all parts of the collection
    # as a matrix.
    # @requires  current object is a collection
    # @param data_matrix [String/Symbol]  optionally specify a data matrix to access besides the default one,
    #                         for example, you might have the default part data, alongside a routing matrix
    # @returns  the data matrix, if one exists
    def get_data_matrix(data_matrix = DATAMATRIX_KEY)
      Matrix.rows(@map[data_matrix])
    end

    # Replace or initialize the data matrix for this object
    # with a custom one.
    # @requires  the current object is a collection
    # `matrix` have the same row column dimensions as the collection
    #
    # @param new_matrix [Matrix]  the new data matrix
    # @param data_matrix [String/Symbol]  optionally specify a data matrix (by key) to access besides the default one,
    #                         for example, you might have the default part data, alongside a routing matrix

    def set_data_matrix(matrix, data_matrix = DATAMATRIX_KEY)
      @map[data_matrix] = matrix.to_a
    end

    # Saves the associations in this map to Aquarium.
    def save
      das = []
      @map.each_key do |key|
        if key == DATAMATRIX_KEY
          das.concat save_data_matrix_alt(@object, @map[key])
        elsif @map[key].is_a? UploadAssoc
          # TODO: update this to lazy associate once aq is updated to hav lazy upload assoc (on master, just not on server yet)
          @object.associate(key, @map[key].tag, @map[key].upload)
        else
          das << @object.lazy_associate(key, @map[key])
        end
      end
      DataAssociation.import(das, on_duplicate_key_update: [:object]) unless das.empty?
      @object.save
      nil
    end

    # saves part_data to the data associations of constituent parts.
    # achieves forward compatibility with AQ Part update
    # built off of set_data_matrix from collection.rb
    def save_data_matrix_alt(coll, matrix, offset: [0, 0])
      pm = coll.part_matrix
      das = []

      uniq_keys = matrix.flatten.map(&:keys).flatten.uniq
      dms_by_key = {}
      uniq_keys.each do |key|
        dms_by_key[key] = coll.data_matrix(key)
      end

      coll.each_row_col(matrix, offset: offset) do |x, y, ox, oy|
        next unless !matrix[x][y].nil? && pm[ox][oy] # this part has das
        matrix[x][y].each do |k, v|
          if pm[ox][oy]
            if dms_by_key[k][ox][oy]
              da = dms_by_key[k][ox][oy]
              da.object = { k => v }.to_json
              das << da
            else
              das << pm[ox][oy].lazy_associate(k, v)
            end
          end
        end
      end

      das
    end

    # Returns an array of all the keys in this map
    def keys
      @map.keys
    end

    # Returns the string representation of the map
    def to_string
      @map.to_s
    end

    alias to_s to_string
  end

  # private class that is used to deal with associating upload objects alongside their tag
  class UploadAssoc
    def initialize(tag, upload)
      @upload = upload
      @tag = tag || {}
    end

    def change_tag(new_tag)
      @tag = new_tag
    end

    attr_reader :upload

    attr_reader :tag
  end

  # Utilizes the part-data matrix of collections to store information about the history of
  # parts of a collection. PartProvenance initializes and relies on two fields of every part-data
  # slot: `source` and `destination`.
  # `source` will store a list of item ids (with rc index if applicable),
  # of all the ingredients used to make this part, and destination will use the same data format
  # to record all of the places this part was used in.
  # Item-Item provenance can technically be recorded as well with this library, but it will not
  # be necessary.
  #
  module PartProvenance
    SOURCE = 'source'
    DESTINATION = 'destination'

    # Record an entry to the provenance data between two parts, or a part and an item.
    # This will populate the destination field of `from`, and the source field
    # of the `to` in their respective associations. If from_coord or to_coord is specified, then
    # the associations of the part of the from/to collection at that coordinate will
    # populated instead.
    #
    # @param opts [Hash]  Arguments specifying which objects to record relation for
    # @option from [Item/Collection]  the item or collection where sample transfer originated
    # @option to [Item/Collection]  the item or collection for destination of sample transfer
    # @option from_coord [Tuple Array]  optionally, specify the coordinate selecting a part of the collection, if `to` was a collection
    # @option to_coord [Tuple Array]  optionally, specify the coordinate selecting a part of the collection, if `from` was a collection
    # @option additional_relation_data [Hash]  optionally, add additional key/value pairs to add to both object's routing data
    #                         for this relation. For example, you might want to specify the volume of the transfer,
    #                         or which colony was picked from a plate
    # @option from_map [AssociationMap]  existing AssociationMap for the given from-object, required to successfully associate provenance to
    #                           the `from` item
    # @option to_map [AssociationMap]  existing AssociationMap for the given to-object, required to successfully associate provenance to
    #                           the `to` item
    def add_provenance(opts = {})
      if opts[:from] == opts[:to] # special case: provenance between two parts on the same collection
        opts[:from_map] = opts[:to_map] # ensure from map and to map are the same object for this case
      end

      # creating information hashes to represent `from` and `to` relationship data
      from_info = serialize_as_simple_tag(opts[:from], opts[:from_coord], opts[:additional_relation_data])
      to_info = serialize_as_simple_tag(opts[:to], opts[:to_coord], opts[:additional_relation_data])

      # in destination field of `from`, add information tag representing `to`
      append_to_association(opts[:from_map], DESTINATION, to_info, coord: opts[:from_coord]) if opts[:from_map]

      # in source field of `to`, add information tag representing `from`
      append_to_association(opts[:to_map], SOURCE, from_info, coord: opts[:to_coord]) if opts[:to_map]
    end

    # Retrieves a list of sources that were used to construct the given part
    # of a Collection
    #
    # @param object [FieldValue/Collection]  the part of interest, or the collection which
    #                 contains the part of interest. For the second case, coord must also be specified
    # @param coord [Tuple Array]  the r,c index of the target part
    def sources(object, coord = nil)
      if coord
        AssociationMap.get_associated_data(object, SOURCE, coord: coord)
      else
        AssociationMap.get_associated_data(object, SOURCE)
      end
    end

    # Retrieves a list of destinations that were made using the given part
    # of a Collection
    #
    # @param object [FieldValue/Collection]  the part of interest, or the collection which
    #                 contains the part of interest. For the second case, coord must also be specified
    # @param coord [Tuple Array]  the r,c index of the target part
    def destinations(object, coord = nil)
      if coord
        AssociationMap.get_associated_data(object, DESTINATION, coord: opts[:coord])
      else
        AssociationMap.get_associated_data(object, DESTINATION)
      end
    end

    # For the given associatable target object, appends or concatenates the given datum_to_append to the association
    # at `key` for that object
    #
    # @param association_map [AssocioationMap]  an AssociationMap that will have its associations appended to.
    # @param key [String/Symbol]  The association key which maps to an appendable object
    # @param datum_to_append [Serializable Object]  the element to append to the list at the value for the given key
    # @param opts [Hash]  additional options
    # @option coord [Tuple array]  coordinate of target part, if association target is a collection
    def append_to_association(association_map, key, datum_to_append, opts = {})
      if opts[:coord] # we will be interacting with the associations of a part of a collection if coord is specified
        association_map.putrc(opts[:coord][0], opts[:coord][1], key, []) if association_map.getrc(opts[:coord][0], opts[:coord][1], key).nil?
        association_map.getrc(opts[:coord][0], opts[:coord][1], key) <<  datum_to_append
      else
        association_map.put(key, []) if association_map.get(key).nil?
        association_map.get(key) << datum_to_append
      end
    end

    # Given an item, or a part of a collection, serializes it into a simple tag which can be used to retrieve it.
    #
    # @param item [Item/FieldValue]  can be either an Item, or
    #                         an i/o object corresponding to a part of a collection, which can be thought of
    #                         as constituting a 'sub item'
    def serialize_as_simple_tag(item, coord, additional_info)
      info = if item.collection? && coord
               { id: item.id, row: coord[0], column: coord[1] }
             elsif (item.is_a? Item) || (item.is_a? Collection)
               { id: item.id }
             else
               raise 'Argument is neither a part nor an item'
             end
      info.merge!(additional_info) unless additional_info.nil?
      info
    end
  end
end
