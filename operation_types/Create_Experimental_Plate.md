# Create Experimental Plate

Documentation here. Start with a paragraph, not a heading or title, as in most views, the title will be supplied by the view.


### Parameters

- **Note:** 

### Outputs


- **96 Well Plate** [Plate]  
  - NO SAMPLE TYPE / <a href='#' onclick='easy_select("Containers", "96 U-bottom Well Plate")'>96 U-bottom Well Plate</a>
  - NO SAMPLE TYPE / <a href='#' onclick='easy_select("Containers", "96 Well Flat Bottom (black)")'>96 Well Flat Bottom (black)</a>

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

# This protocol is for creating a 96 well plate that can then be linked to 'Plate Reader Measurement'

class Protocol
    OUTPUT = '96 Well Plate'
    NOTE = 'Note:'
    # SAMPLE_MATRIX = 'Do you know what samples are in each well?'
  def main

    operations.make
    
    operations.each {|op|
        new_experimental_plt = op.output(OUTPUT).collection
        note = op.input(NOTE).val.to_s
        if note != '' || note != nil || note != ' '
            note_entered = true
            key = 'Note'
            Item.find(new_experimental_plt.id).associate key.to_sym, note
        end
        show {
            title "New Experimental Plate Created"
            separator
            note "Output Item: <b>#{new_experimental_plt}</b>"
            bullet "Output Object Type: <b>#{new_experimental_plt.object_type.name}</b>"
            (note_entered) ? (bullet "Note: <b>#{note}</b>") : nil
        }
    }
    
    return {}
    
  end # Main
end # Class


    # associate_to_item(in_collection, key, upload)
    # associate_to_plans(key, upload)
    # associate_PlateReader_Data(upload, cal_plate, method, timepoint=nil)

```
