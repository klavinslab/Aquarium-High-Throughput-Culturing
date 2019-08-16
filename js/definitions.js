var config = {

  tagline: "The Laboratory</br>Operating System",
  documentation_url: "http://localhost:4000/aquarium",
  title: "Aquarium High Throughput Culturing",
  navigation: [

    {
      category: "Overview",
      contents: [
        { name: "Introduction", type: "local-md", path: "README.md" },
        { name: "About this Workflow", type: "local-md", path: "ABOUT.md" },
        { name: "License", type: "local-md", path: "LICENSE.md" },
        { name: "Issues", type: "external-link", path: 'https://github.com/klavinslab/Aquarium-High-Throughput-Culturing/issues' }
      ]
    },

    

      {

        category: "Operation Types",

        contents: [

          
            {
              name: 'Apply Experimental Condition',
              path: 'operation_types/Apply_Experimental_Condition' + '.md',
              type: "local-md"
            },
          
            {
              name: 'Define Culture Conditions',
              path: 'operation_types/Define_Culture_Conditions' + '.md',
              type: "local-md"
            },
          
            {
              name: 'Dilute Collection',
              path: 'operation_types/Dilute_Collection' + '.md',
              type: "local-md"
            },
          
            {
              name: 'Experimental Recovery',
              path: 'operation_types/Experimental_Recovery' + '.md',
              type: "local-md"
            },
          
            {
              name: 'Flow Cytometry Calibration',
              path: 'operation_types/Flow_Cytometry_Calibration' + '.md',
              type: "local-md"
            },
          
            {
              name: 'Flow Cytometry Measurement',
              path: 'operation_types/Flow_Cytometry_Measurement' + '.md',
              type: "local-md"
            },
          
            {
              name: 'Inoculate Culture Plate',
              path: 'operation_types/Inoculate_Culture_Plate' + '.md',
              type: "local-md"
            },
          
            {
              name: 'Make Glycerol Stock Plates',
              path: 'operation_types/Make_Glycerol_Stock_Plates' + '.md',
              type: "local-md"
            },
          
            {
              name: 'Plate Reader Calibration',
              path: 'operation_types/Plate_Reader_Calibration' + '.md',
              type: "local-md"
            },
          
            {
              name: 'Plate Reader Measurement',
              path: 'operation_types/Plate_Reader_Measurement' + '.md',
              type: "local-md"
            },
          
            {
              name: 'To Single Colonies',
              path: 'operation_types/To_Single_Colonies' + '.md',
              type: "local-md"
            },
          

        ]

      },

    

    

      {

        category: "Libraries",

        contents: [

          
            {
              name: 'AssociationManagement',
              path: 'libraries/AssociationManagement' + '.html',
              type: "local-webpage"
            },
          
            {
              name: 'CollectionDisplay',
              path: 'libraries/CollectionDisplay' + '.html',
              type: "local-webpage"
            },
          
            {
              name: 'CultureComposition',
              path: 'libraries/CultureComposition' + '.html',
              type: "local-webpage"
            },
          
            {
              name: 'Debug',
              path: 'libraries/Debug' + '.html',
              type: "local-webpage"
            },
          
            {
              name: 'FlowCytometryCalibration',
              path: 'libraries/FlowCytometryCalibration' + '.html',
              type: "local-webpage"
            },
          
            {
              name: 'FlowCytometryConstants',
              path: 'libraries/FlowCytometryConstants' + '.html',
              type: "local-webpage"
            },
          
            {
              name: 'FlowCytometryHelper',
              path: 'libraries/FlowCytometryHelper' + '.html',
              type: "local-webpage"
            },
          
            {
              name: 'FlowCytometrySoftware',
              path: 'libraries/FlowCytometrySoftware' + '.html',
              type: "local-webpage"
            },
          
            {
              name: 'HighThroughputHelper',
              path: 'libraries/HighThroughputHelper' + '.html',
              type: "local-webpage"
            },
          
            {
              name: 'InstrumentHelper',
              path: 'libraries/InstrumentHelper' + '.html',
              type: "local-webpage"
            },
          
            {
              name: 'PlateReaderCalibration',
              path: 'libraries/PlateReaderCalibration' + '.html',
              type: "local-webpage"
            },
          
            {
              name: 'PlateReaderConstants',
              path: 'libraries/PlateReaderConstants' + '.html',
              type: "local-webpage"
            },
          
            {
              name: 'PlateReaderHelper',
              path: 'libraries/PlateReaderHelper' + '.html',
              type: "local-webpage"
            },
          
            {
              name: 'PlateReaderSoftware',
              path: 'libraries/PlateReaderSoftware' + '.html',
              type: "local-webpage"
            },
          
            {
              name: 'Units',
              path: 'libraries/Units' + '.html',
              type: "local-webpage"
            },
          

        ]

    },

    

    
      { category: "Sample Types",
        contents: [
          
            {
              name: 'Beads',
              path: 'sample_types/Beads'  + '.md',
              type: "local-md"
            },
          
            {
              name: 'DNA Library',
              path: 'sample_types/DNA_Library'  + '.md',
              type: "local-md"
            },
          
            {
              name: 'E coli strain',
              path: 'sample_types/E_coli_strain'  + '.md',
              type: "local-md"
            },
          
            {
              name: 'Fragment',
              path: 'sample_types/Fragment'  + '.md',
              type: "local-md"
            },
          
            {
              name: 'Media',
              path: 'sample_types/Media'  + '.md',
              type: "local-md"
            },
          
            {
              name: 'Oligo Pool',
              path: 'sample_types/Oligo_Pool'  + '.md',
              type: "local-md"
            },
          
            {
              name: 'Plasmid',
              path: 'sample_types/Plasmid'  + '.md',
              type: "local-md"
            },
          
            {
              name: 'Plate Reader Calibration Solution',
              path: 'sample_types/Plate_Reader_Calibration_Solution'  + '.md',
              type: "local-md"
            },
          
            {
              name: 'Primer',
              path: 'sample_types/Primer'  + '.md',
              type: "local-md"
            },
          
            {
              name: 'Yeast Strain',
              path: 'sample_types/Yeast_Strain'  + '.md',
              type: "local-md"
            },
          
        ]
      },
      { category: "Containers",
        contents: [
          
            {
              name: '1X LUDOX Aliquot',
              path: 'object_types/1X_LUDOX_Aliquot'  + '.md',
              type: "local-md"
            },
          
            {
              name: '1mM Fluorescein Stock',
              path: 'object_types/1mM_Fluorescein_Stock'  + '.md',
              type: "local-md"
            },
          
            {
              name: '800 mL Liquid',
              path: 'object_types/800_mL_Liquid'  + '.md',
              type: "local-md"
            },
          
            {
              name: '96 U-bottom Well Plate',
              path: 'object_types/96_U-bottom_Well_Plate'  + '.md',
              type: "local-md"
            },
          
            {
              name: '96 Well Flat Bottom (black)',
              path: 'object_types/96_Well_Flat_Bottom_black_'  + '.md',
              type: "local-md"
            },
          
            {
              name: '96 Well PCR Plate',
              path: 'object_types/96_Well_PCR_Plate'  + '.md',
              type: "local-md"
            },
          
            {
              name: 'Bead droplet dispenser',
              path: 'object_types/Bead_droplet_dispenser'  + '.md',
              type: "local-md"
            },
          
            {
              name: 'Diluted beads',
              path: 'object_types/Diluted_beads'  + '.md',
              type: "local-md"
            },
          
            {
              name: 'E coli Glycerol Stock',
              path: 'object_types/E_coli_Glycerol_Stock'  + '.md',
              type: "local-md"
            },
          
            {
              name: 'E coli Plate of Plasmid',
              path: 'object_types/E_coli_Plate_of_Plasmid'  + '.md',
              type: "local-md"
            },
          
            {
              name: 'Eppendorf 96 Deepwell Plate',
              path: 'object_types/Eppendorf_96_Deepwell_Plate'  + '.md',
              type: "local-md"
            },
          
            {
              name: 'Yeast Glycerol Stock',
              path: 'object_types/Yeast_Glycerol_Stock'  + '.md',
              type: "local-md"
            },
          
            {
              name: 'Yeast Overnight Suspension',
              path: 'object_types/Yeast_Overnight_Suspension'  + '.md',
              type: "local-md"
            },
          
            {
              name: 'Yeast Plate',
              path: 'object_types/Yeast_Plate'  + '.md',
              type: "local-md"
            },
          
        ]
      }
    

  ]

};
