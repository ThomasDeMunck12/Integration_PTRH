using DataFrames
using CSV
using NPZ

I = 49
J = I^2  
S = 15

Min_ServiceT = 2.0 #minimum initial service time 
Max_AdditionalT = 0.5 #maximum additional service time 
Min_Reduction = 0.0 #minimum discount
Max_PickupT = 10.0 #maximum pickup time

PickupT = npzread("data_synthetic_benef/PickupT.npy") #pickup time for D route r≡(i,j)
ServiceT = npzread("data_synthetic_benef/ServiceT.npy") #service time for customer type j
origin = npzread("data_synthetic_benef/origin.npy") #origin of customer type j. 
destination = npzread("data_synthetic_benef/destination.npy") #destination of customer type j. 
transfer_FM = npzread("data_synthetic_benef/transfer_FM.npy") #new customer type after using F route f≡(j,i).
transfer_LM = npzread("data_synthetic_benef/transfer_LM.npy") #new customer type after using L route l≡(j,i).
DR_bis = npzread("data_synthetic_benef/DR_bis.npy")
LC_bis = npzread("data_synthetic_benef/LC.npy") # LC_{ji}
FC_bis = npzread("data_synthetic_benef/FC.npy") # FC_{ji}
DT_bis = npzread("data_synthetic_benef/DT.npy") #dispatching time
LT_bis = npzread("data_synthetic_benef/LT.npy")
FT_bis = npzread("data_synthetic_benef/FT.npy")
RT_bis = npzread("data_synthetic_benef/RT.npy")

#Instance-dependent parameters 
id = 1

#id = Base.parse(Int, ENV["SLURM_ARRAY_TASK_ID"])

instances_id = Dict() 

for (idx,(a, b)) in collect(enumerate(Iterators.product(collect(1:30), [1, 2])))
    push!(instances_id, idx => (a, b))
end

(Day, Pattern) = instances_id[id] 

T_horizon = 24
T_offline = 24
T = 24

if Pattern == 1
    D_train = npzread("data_synthetic_benef/D_train_outside_in.npy")
    D_test = npzread("data_synthetic_benef/D_test_outside_in.npy")

elseif Pattern == 2
    D_train = npzread("data_synthetic_benef/D_inside_out.npy")
    D_test = npzread("data_synthetic_benef/D_inside_out.npy")
end

D_train = D_train[1:T_horizon,:,1+(Day-1)*S:Day*S]
D_test = D_test[1:T_offline, :, Day]

N_drivers = npzread("data_synthetic_benef/N_2.npy")
