using DataFrames
using CSV
using NPZ

I = 49
J = I^2  
S = 15

PickupT = npzread("data_synthetic_benef/PickupT.npy") #pickup time for D route r≡(i,j)
ServiceT = npzread("data_synthetic_benef/ServiceT.npy") #service time for customer type j
origin = npzread("data_synthetic_benef/origin.npy") #origin of customer type j. 
destination = npzread("data_synthetic_benef/destination.npy") #destination of customer type j. 
transfer_FM = npzread("data_synthetic_benef/transfer_FM.npy") #new customer type after using F route f≡(j,i).
transfer_LM = npzread("data_synthetic_benef/transfer_LM.npy") #new customer type after using L route l≡(j,i).
DR_bis = npzread("data_synthetic_benef/DR_bis.npy")
DT_bis = npzread("data_synthetic_benef/DT.npy") #dispatching time
LT_bis = npzread("data_synthetic_benef/LT.npy")
FT_bis = npzread("data_synthetic_benef/FT.npy")
RT_bis = npzread("data_synthetic_benef/RT.npy")

#Instance-dependent parameters 
id = 1

#id = Base.parse(Int, ENV["SLURM_ARRAY_TASK_ID"])

instances_id = Dict() 

for (idx,(a, b)) in collect(enumerate(Iterators.product(collect(1:30), [5.0, 10.0])))
    push!(instances_id, idx => (a, b))
end

(Day, Conditions) = instances_id[id] 

T_horizon = 24
T_offline = 24
T = 24

if Conditions == 5.0
    Min_Reduction = 5.0 #minimum discount
    LC_bis = npzread("data_synthetic_benef/LC_1.npy") # LC_{ji}
    FC_bis = npzread("data_synthetic_benef/FC_1.npy") # FC_{ji}
elseif Conditions == 10.0
    Min_Reduction = 10.0 #minimum discount
    LC_bis = npzread("data_synthetic_benef/LC_2.npy") # LC_{ji}
    FC_bis = npzread("data_synthetic_benef/FC_2.npy") # FC_{ji}
end

Min_ServiceT = 2.0
Max_AdditionalT = 0.5 #maximum additional service time 
#Min_Reduction = 0.0 #minimum discount
Max_PickupT = 10.0 #maximum pickup time

D_train = npzread("data_synthetic_benef/D_train_2.npy")
D_test = npzread("data_synthetic_benef/D_test_2.npy")

D_train = D_train[1:T_horizon,:,1+(Day-1)*S:Day*S]
D_test = D_test[1:T_offline, :, Day]

N_drivers = npzread("data_synthetic_benef/N_2.npy")
