module CollectionDisplay
  def create_collection_table collection
    size = collection.object_type.rows * collection.object_type.columns
    slots = (1..size).to_a
    slots.each_slice(collection.object_type.columns).map do |row|
      row.map do |col|
        {content: col, class: 'td-empty-slot'}
      end
    end
  end

  def highlight tbl, row, col, id
    tbl[row][col] = {content: id, class: 'td-filled-slot', check: true}
  end

  # [r,c,x] list
  def highlight_rcx collection, rcx_list
    tbl = create_collection_table collection
    rcx_list.each do |r, c, x|
      highlight tbl, r, c, x
    end
    tbl
  end

  def highlight_rc collection, rc_list, &rc_block
    rcx_list = rc_list.map { |r, c|
      block_given? ? [r, c, yield(r, c)] : [r, c, ""]
    }
    highlight_rcx collection, rcx_list
  end

  def highlight_non_empty collection, &rc_block
    highlight_rc collection, collection.get_non_empty, &rc_block
  end

  def highlight_collection ops, id_block=nil, &fv_block
    g = ops.group_by { |op| fv_block.call(op).collection }
    tables = g.map do |collection, grouped_ops|
      rcx_list = grouped_ops.map do |op|
        fv = fv_block.call(op)
        id = id_block.call(op) if id_block
        id ||= fv.sample.id
        [fv.row, fv.column, id]
      end
      tbl = highlight_rcx collection, rcx_list
      [collection, tbl]
    end
    tables
  end

  def r_c_to_slot collection, r, c
    rows, cols = collection.dimensions = collection.object_type.rows
    r*cols + c+1
  end
  
  
  
  
  def create_alpha_numeric_table(collection)
    size = collection.object_type.rows * collection.object_type.columns
    slots = (1..size).to_a
    alpha_r = ('A'..'H').to_a
    slots.each_slice(collection.object_type.columns).each_with_index.map do |row, r_idx|
      row.each_with_index.map do |col, c_idx|
        {content: "#{alpha_r[r_idx]}#{c_idx + 1}", class: 'td-empty-slot'}
      end
    end
  end
  
  def highlight_alpha_rc collection, rc_list, &rc_block
    rcx_list = rc_list.map { |r, c|
      block_given? ? [r, c, yield(r, c)] : [r, c, ""]
    }
    highlight_alpha_rcx(collection, rcx_list)
  end
  
  def highlight_alpha_rcx(collection, rcx_list)
     tbl = create_alpha_numeric_table(collection)
     rcx_list.each do |r, c, x|
         highlight tbl, r, c, x
     end
     return tbl
  end

    def highlight_alpha_non_empty collection, &rc_block
        highlight_alpha_rc collection, collection.get_non_empty, &rc_block
    end
      
end