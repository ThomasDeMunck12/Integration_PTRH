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

PickupT = npzread("data_synthetic_PT/PickupT.npy") #pickup time for D route r≡(i,j)
ServiceT = npzread("data_synthetic_PT/ServiceT.npy") #service time for customer type j
origin = npzread("data_synthetic_PT/origin.npy") #origin of customer type j. 
destination = npzread("data_synthetic_PT/destination.npy") #destination of customer type j. 
transfer_FM = npzread("data_synthetic_PT/transfer_FM.npy") #new customer type after using F route f≡(j,i).
transfer_LM = npzread("data_synthetic_PT/transfer_LM.npy") #new customer type after using L route l≡(j,i).
DR_bis = npzread("data_synthetic_PT/DR_bis.npy")
LC_bis = npzread("data_synthetic_PT/LC.npy") # LC_{ji}
FC_bis = npzread("data_synthetic_PT/FC.npy") # FC_{ji}
DT_bis = npzread("data_synthetic_PT/DT.npy") #dispatching time
D_train = npzread("data_synthetic_PT/D_train.npy")
D_test = npzread("data_synthetic_PT/D_test.npy")

#Instance-dependent parameters 
id = 1

#id = Base.parse(Int, ENV["SLURM_ARRAY_TASK_ID"])

instances_id = Dict() 

for (idx,(a, b)) in collect(enumerate(Iterators.product(collect(1:30), [20, 40, 60])))
    push!(instances_id, idx => (a, b))
end

(Day, Speed) = instances_id[id] 

#Speed = 30 
Frequency = 2 
Network = 1 

T_horizon = 24
T_offline = 24
T = 24

if Speed == 20
    LT_bis = npzread("data_synthetic_PT/LT_1.npy")
    FT_bis = npzread("data_synthetic_PT/FT_1.npy")
    RT_bis = npzread("data_synthetic_PT/RT_1.npy")

elseif Speed == 40
    LT_bis = npzread("data_synthetic_PT/LT_3.npy")
    FT_bis = npzread("data_synthetic_PT/FT_3.npy")
    RT_bis = npzread("data_synthetic_PT/RT_3.npy")

elseif Speed == 60
    LT_bis = npzread("data_synthetic_PT/LT_4.npy")
    FT_bis = npzread("data_synthetic_PT/FT_4.npy")
    RT_bis = npzread("data_synthetic_PT/RT_4.npy")
end

D_train = D_train[1:T_horizon,:,5:15]
D_test = D_test[1:T_offline, :, Day]

N_drivers = npzread("data_synthetic_PT/N.npy")
