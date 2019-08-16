# High Throughput Culturing

This Aquarium workflow is comprised of operations that abstract and automate the setup, execution, and measurements taken during a high throughput microbial culturing experiment. This assesment will phenotypically characterize the genetically modified cultures found in the high throughput container, under the user defined experimental conditions, by taking __Flow Cytometry__ & __Plate Reader__ measurements. Parameterized experimental conditions include combinations of __Media__, __Strain__, __Inducer(s)__, & __Antibiotics__. After Experimental Conditions have been defined a high throughput container is inoculated, and a virtual 96 well plate with sorted representations of experimental microbial cultures is generated. The inoculation sorting algorithm takes into consideration manual pipetting by grouping replicates by input item and induction conditions (by total moles of inducer used for condition).

## Planning

To get started with planning your own High Throughput Culturing experiment, vist the GitHub Repository below.
[Jellyfish](https://github.com/EribertoLopez/Jellyfish "High Throughput Culturing Planning")

## Execution

Scripts automate the planning of 'Define Culture Conditions' operations which take JSON parsable parameters 
![High Throughput Culturing Plan](/docs/_images/plan_example.png?raw=true "High Throughput Culturing Plan")

Once planned the operations sort and organize conditions into a high throughput container.
![Inoculate Culture Plate Example](/docs/_images/inoculate_culture_plate_example.png?raw=true "Inoculate Culture Plate Example")

After execution, the virtual container will have representations of user defined experimental conditions.
![Culture Component Representations](/docs/_images/cultureComponent_representation.png?raw=true "Culture Component Representations")
