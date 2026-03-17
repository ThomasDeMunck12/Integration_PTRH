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

DT_bis = npzread("data_synthetic_base/DT.npy") #dispatching time
PickupT = npzread("data_synthetic_base/PickupT.npy") #pickup time for D route r≡(i,j)
ServiceT = npzread("data_synthetic_base/ServiceT.npy") #service time for customer type j
origin = npzread("data_synthetic_base/origin.npy") #origin of customer type j. 
destination = npzread("data_synthetic_base/destination.npy") #destination of customer type j. 
transfer_FM = npzread("data_synthetic_base/transfer_FM.npy") #new customer type after using F route f≡(j,i).
transfer_LM = npzread("data_synthetic_base/transfer_LM.npy") #new customer type after using L route l≡(j,i).
LC_bis = npzread("data_synthetic_base/LC.npy") # LC_{ji}
FC_bis = npzread("data_synthetic_base/FC.npy") # FC_{ji}
DR_bis = npzread("data_synthetic_base/DR_bis.npy")
FT_bis = npzread("data_synthetic_base/FT.npy")
LT_bis = npzread("data_synthetic_base/LT.npy")

#Instance-dependent parameters 
id = 1

#id = Base.parse(Int, ENV["SLURM_ARRAY_TASK_ID"])

instances_id = Dict() 

for (idx,(a, b, c)) in collect(enumerate(Iterators.product(collect(1:30), [0.5, 1.0, 2.0], [0.5, 1.0, 2.0])))
    push!(instances_id, idx => (a, b, c))
end

(Day, Supply, Demand) = instances_id[id] 

T_horizon = 24
T_offline = 24
T = 24

if Demand == 0.5
    D_train = npzread("data_synthetic_base/D_train_1.npy")
    D_test = npzread("data_synthetic_base/D_test_1.npy")

elseif Demand == 1.0
    D_train = npzread("data_synthetic_base/D_train_2.npy")
    D_test = npzread("data_synthetic_base/D_test_2.npy")

elseif Demand == 2.0
    D_train = npzread("data_synthetic_base/D_train_3.npy")
    D_test = npzread("data_synthetic_base/D_test_3.npy")
end

D_train = D_train[1:T_horizon,:,1+(Day-1)*S:Day*S]
D_test = D_test[1:T_offline, :, Day]

if Supply == 0.5
    N_drivers = npzread("data_synthetic_base/N_1.npy")
elseif Supply == 1.0
    N_drivers = npzread("data_synthetic_base/N_2.npy")
elseif Supply == 2.0
    N_drivers = npzread("data_synthetic_base/N_3.npy")
end