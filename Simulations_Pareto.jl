using Distributed
using Statistics
#addprocs(3)
#@everywhere
#@everywhere
#@everywhere

cd("C:\\Users\\thoma\\OneDrive\\Desktop\\PhD\\Output\\Papier 3 - Numerical Experiments/") 

include("Functions_Pareto.jl")
include("Data_Loading_Pareto.jl")

function RunSimulations(id::Int64, Demand::Float64, Supply::Float64, Day::Int64)
   #Simulation global parameters
   set_service = [1, 2, 3, 4]
   α = 0.8

   #Set initial states
   N_D = zeros(T+1, I)  #drivers 
   N_D[1,:] = N_drivers[:, Day] #drivers available
   N_F = zeros(T, J) #FM customers in transit.

   Computing_time = @elapsed begin
     Objective_offline, Objective_offline1, Objective_offline2 = RunOffline(T_offline, N_D, N_F, D_test, α)
   end 
   println(Objective_offline, " - ", Objective_offline1, " - ", Objective_offline2)
    #objective_offline = 1.0

   df_7 = DataFrame(ID = Int[], α = Float64[], 
   Demand = Float64[], Supply = Float64[], Day = Int[],
   Computing_time = Float64[], 
   Objective_offline = Float64[], Objective_offline1 = Float64[], Objective_offline2 = Float64[])

   push!(df_7, [id, α, Demand, Supply, Day, Computing_time, Objective_offline, Objective_offline1, Objective_offline2])
   CSV.write("results/data_base_7.csv", df_7, append = true)
   return nothing
   df_8 = DataFrame(ID = Int[], Service = Int64[], α = Float64[],
   Demand = Float64[], Supply = Float64[], Day = Int[],
   Computing_time = Float64[], 
   Objective_online = Float64[], Objective_online1 = Float64[], Objective_online2 = Float64[], 
   Number_drivers = Float64[], FM_customers = Float64[], LM_customers = Float64[], D2D_customers = Float64[], 
   Dispatched_drivers = Float64[], Rejected_customers = Float64[], Canceled_customers = Float64[], Potential_demand = Int[], 
   Service_rate = Float64[], FM_rate = Float64[], LM_rate = Float64[])
   
   for (i, (s,)) in collect(enumerate(Iterators.product(set_service)))
     N_D = zeros(T+1, I)  #drivers 
     N_D[1,:] = N_drivers[:, Day] #drivers available
     N_F = zeros(T, J) #FM customers in transit.
     println("Service: ", s[1])
     service = s[1]
     Q = 7
     S = 10
     Max_DispatchingRoutesPerCust = 8 #dispatching routes
     l_shaped = true

     Computing_time = @elapsed begin
       x, y, z, v, w, N, F, Dispatched_drivers, FM_customers, LM_customers, D2D_customers, Rejected_customers, Canceled_customers,
        Objective_online, Objective_online1, Objective_online2 = RunOnline(T_horizon, Max_DispatchingRoutesPerCust, S, Q, N_D, N_F, D_test, D_train, l_shaped, service, α)
     end 

     Potential_demand = sum(D_test[1:T_horizon, :])
     Service_rate = (FM_customers + LM_customers + D2D_customers)./Potential_demand
     FM_rate = (FM_customers)/(FM_customers + LM_customers + D2D_customers)
     LM_rate = (LM_customers)/(FM_customers + LM_customers + D2D_customers)
     Number_drivers = sum(N_drivers[:, Day])

     push!(df_8, [id, service, α, Demand, Supply, Day, 
     Computing_time/T_horizon, Objective_online, Objective_online1, Objective_online2,
     Number_drivers, FM_customers, LM_customers, D2D_customers, 
     Dispatched_drivers, Rejected_customers, Canceled_customers, Potential_demand, Service_rate, FM_rate, LM_rate])
   end
   CSV.write("results/data_base_8.csv", df_8, append = true)
   return nothing  
end

RunSimulations(id, Demand, Supply, Day)