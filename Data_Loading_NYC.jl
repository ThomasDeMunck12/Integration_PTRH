using DataFrames
using CSV
using NPZ

I = 94
J = I^2  

S = 10

Min_ServiceT = 2.0 #minimum initial service time 
Max_AdditionalT = 0.5 #maximum additional service time 
Min_Reduction = 0.0 #minimum discount
Max_PickupT = 2.0 #maximum pickup time

#delta = 0.5

ServiceT = npzread("data_NYC/ServiceT.npy") #service time for customer type j
PickupT = npzread("data_NYC/PickupT.npy") #service time for customer type j
origin = Int32.(npzread("data_NYC/origin.npy")) #origin of customer type j. 
destination = Int32.(npzread("data_NYC/destination.npy")) #destination of customer type j. 
transfer_FM = Int32.(npzread("data_NYC/transfer_FM.npy")) #new customer type after using F route f≡(j,i).
transfer_LM = Int32.(npzread("data_NYC/transfer_LM.npy")) #new customer type after using L route l≡(j,i).
DR_bis = npzread("data_NYC/DR_bis.npy")
LC_bis = npzread("data_NYC/LC.npy") # LC_{ji}
FC_bis = npzread("data_NYC/FC.npy") # FC_{ji}
DT_bis = npzread("data_NYC/DT.npy") #dispatching time
D_train = npzread("data_NYC/D_train.npy")
D_test = npzread("data_NYC/D_test.npy")
N_train = npzread("data_NYC/N_train.npy")
N_test = npzread("data_NYC/N_test.npy")
N_drivers = npzread("data_NYC/N.npy")
FT_bis = npzread("data_NYC/FT.npy")
LT_bis = npzread("data_NYC/LT.npy")
RT_bis = npzread("data_NYC/RT.npy")

#Instance-dependent parameters 
id = 1

#id = Base.parse(Int, ENV["SLURM_ARRAY_TASK_ID"])
instances_id = Dict()

for (idx,(a, b, c, d)) in collect(enumerate(Iterators.product([2], [7], 0.1:0.1:1.0, [0.0, 0.2, 0.6, 1.0])))
    push!(instances_id, idx => (a, b, c, d))
end

(Day, Q, delta, alpha) = instances_id[id] 

T_horizon = 40
T_offline = 40
T = 40

N_train = N_train[1:T_horizon,:, 16-S:end]
N_test = N_test[1:T_offline,:, Day]

D_train = D_train[1:T_horizon,:,[1, 5, 6, 7, 10, 11, 12, 13, 14, 15]]
D_test = D_test[1:T_offline, :, Day]
