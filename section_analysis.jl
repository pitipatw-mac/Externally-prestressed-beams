using LinearAlgebra
include("utilities/utilityFunctions.jl")
include("utilities/resistanceCalculations.jl")

# using Plots
# x = range(0,10000,length=100)
# y = get_fps.(x,1000.,0.02,1000)
# plot(x,y)

# inputs from Grasshopper
# Probably going to use JSON, (Dictionary mapping?)
# Concrete Properties
fc′= 56 #MPa
ρ_concrete = 23 #kg/m³
high_strength = false
ϵ_cu = 0.003 # Maximum compressive strain for Concrete
ϵ_ce = 0.005 # Maximum tensile strain for Concrete :Obsolete

####half-scale model
A_l = 6179 #mm, single piece

# Steel Properties
# use tuple for mutiple rods
PTsteelᵣ= [9,0,0] #dia mm 
PTsteel_area = pi .* PTsteelᵣ.^2 ./ 4

# Postion of the vertical axis relative section's centroid
# 1.2 Changes PTpos to ecc, from the "Eccentricity"
# aka e : eccentricity [ratio]
ecc   = [80., -5., -5.] # mm 
# "Should" be symmetrical such that e2 = e3 = e1*cos60
# Indexing
# ................
# ..x(2)...x(3)...
# ................
# ......x(1)......
fpe = [-800, -0, -0] #MPa
fpu = [1860, 1860, 1860] #MPa
 steel_modulus = 200000 #MPa
Force_steel_each = fpe .* PTsteel_area ./ 1000 #[kN]

# load detail
begin
    DL = 0.0070 # [N/mm²] = 7kPa  #could use the actual one
    LL = 0.0048 # [N/mm²] = 4.8kPa
    # buidling detail
    BayDepth = 2000 # [mm]
    SpanLength = 3000 # [mm]

    w_dead = BayDepth * DL
    w_live = BayDepth * LL
    w_total = w_dead + w_live
    M_dead  = w_dead * SpanLength^2 / 8
    M_total = w_total * SpanLength^2 / 8
end

#concrete stiffness
concrete_modulus = getEc(fc′, ρ_concrete, high_strength)

# section properties
begin
    Total_area = 200000 #mm2
    centroid = 0 #origin in y axis

    #moment of inertia
    I = 2000000 #mm4

    #distance to extreme fibres
    ct = 20 #mm
    cb = 40 #mm

    #section modulus
    st = I / ct #mm
    sb = I / cb #mm
end

###### NO INPUTs AFTER THIS LINE ######
## Calculation process
# Start of Pure Axial Capacity Calculation

Ø₁ = phi1(fc′) #this isn't being used
Factored_AxialCap = axialCapacity(fc′, Total_area, PTsteel_area, fpe)
println("Factored Axial Capacity: $Factored_AxialCap kN")

# End of Pure Axial Capacity Calculation

# Start of Moment Capacity Calculation
# input section divisions started from the top.

###THESE ARE DUMMY VALUES/VARIABLES
# section_division = collect(range(1,50, length = 901))
# section_centroid = collect(range(1,50, length = 901))

 section_division = collect(Float64, 1:2000)
section_centroid = collect(range(1, 50, length = 2000))

#Stress of each straind
fps₁ = 1000
fps₂ = 300
fps₃ = 300 

#Collect and determine total force
fps = [fps₁, fps₂, fps₃]
Ext_steel_force = sum(fps .* PTsteel_area)

#find target compression centroid to match tension force
target = Ext_steel_force
n = size(section_division, 1)
println(n)

#total required compression area
target_area = sum(PTsteel_area .* fps ./ fc′./ 0.85)

#iterate through a search table of section areas and centroid locations
centroid = compressioncentroid(target_area, section_division, section_centroid)

arm = ecc .- centroid # [mm] tuple of lenght of moment arm

strains = fps ./ concrete_modulus

Ø₂= phi2(strains)

Factored_Moment = sum(Ø₂ .* arm .* fps .* PTsteel_area) / 1e6 #kNm

# 2 and 3 might be discarded, i.e. fps₁ and fps₂ = 0 

# End of Moment capacity Calculation

# Constraints check
c_check = servicecheck(ecc, 
    Force_steel_each,
    Total_area,
    st,
    sb,
    M_dead,
    M_total,
    fc′)
        
 