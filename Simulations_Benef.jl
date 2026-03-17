using Distributed
using Statistics
#addprocs(3)
#@everywhere
#@everywhere
#@everywhere

cd("C:\\Users\\thoma\\OneDrive\\Desktop\\PhD\\Output\\Papier 3 - Numerical Experiments/") 

include("Functions_Benef.jl")
include("Data_Loading_Benef.jl")

function RunSimulations(id::Int64, Demand::Float64, Supply::Float64, Day::Int64)

   #Simulation global parameters
   set_service = [1, 2, 3, 4]

   #Set initial states
   N_D = zeros(T+1, I)  #drivers 
   N_D[1,:] = N_drivers[:, Day] #drivers available
   N_F = zeros(T, J) #FM customers in transit.

   objective_offline = RunOffline(T_offline, N_D, N_F, D_test)
   #objective_offline = 1.0

   df_6 = DataFrame(ID = Int[], Service = Int64[], Demand = Float64[], Supply = Float64[], Day = Int[],
   Computing_time = Float64[], Empirical_ratio = Float64[], 
   Number_drivers = Float64[], FM_customers = Float64[], LM_customers = Float64[], D2D_customers = Float64[], 
   Dispatched_drivers = Float64[], Rejected_customers = Float64[], Potential_demand = Int[], Service_rate = Float64[], FM_rate = Float64[], LM_rate = Float64[])
   for (i, (s,)) in collect(enumerate(Iterators.product(set_service)))
     N_D = zeros(T+1, I)  #drivers 
     N_D[1,:] = N_drivers[:, Day] #drivers available
     N_F = zeros(T, J) #FM customers in transit.
     println("Service: ", s[1])
     service = s[1]
     Q = 7
     S = 10
     Max_DispatchingRoutesPerCust = 8 #dispatching routes
     l_shaped = false

     Computing_time = @elapsed begin
       x, y, z, w, N, F, Dispatched_drivers, FM_customers, LM_customers, D2D_customers, Rejected_customers, objective_online = RunOnline(T_horizon, Max_DispatchingRoutesPerCust, S, Q, N_D, N_F, D_test, D_train, l_shaped, service)
     end 

     Potential_demand = sum(D_test[1:T_horizon, :])
     Empirical_ratio = objective_online/objective_offline
     Service_rate = (FM_customers + LM_customers + D2D_customers)./Potential_demand
     FM_rate = (FM_customers)/(FM_customers + LM_customers + D2D_customers)
     LM_rate = (LM_customers)/(FM_customers + LM_customers + D2D_customers)
     Number_drivers = sum(N_drivers[:, Day])

     push!(df_6, [id, service, Demand, Supply, Day, 
     Computing_time/T_horizon, Empirical_ratio,
     Number_drivers, FM_customers, LM_customers, D2D_customers, 
     Dispatched_drivers, Rejected_customers, Potential_demand, Service_rate, FM_rate, LM_rate])
   end
   CSV.write("results/data_base_6.csv", df_6, append = true)
   return nothing  
end

RunSimulations(id, Demand, Supply, Day)