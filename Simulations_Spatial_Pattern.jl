using Distributed
using Statistics
#addprocs(3)
#@everywhere
#@everywhere
#@everywhere

#cd("C:\\Users\\thoma\\OneDrive\\Desktop\\PhD\\Output\\Papier 3 - Numerical Experiments/") 

include("Functions_Pareto.jl")
include("Data_Loading_Pattern.jl")

function RunSimulations(id::Int64, Pattern::Int64, Day::Int64)

   #Simulation global parameters
   set_service = [1, 4]
   α = 1.0
   wait = rand(1:120)
   sleep(wait)
   #Set initial states
   N_D = zeros(T+1, I)  #drivers 
   N_D[1,:] = N_drivers[:, Day] #drivers available
   N_F = zeros(T, J) #FM customers in transit.

   Computing_time = @elapsed begin
     Objective_offline, Objective_offline1, Objective_offline2 = RunOffline(T_offline, N_D, N_F, D_test, α)
   end 
    #objective_offline = 1.0

   df_off = DataFrame(ID = Int[], α = Float64[], 
   Pattern = Int[], Day = Int[],
   Computing_time = Float64[], 
   Objective_offline = Float64[], Objective_offline1 = Float64[], Objective_offline2 = Float64[])

   push!(df_off, [id, α, Pattern, Day, Computing_time, Objective_offline, Objective_offline1, Objective_offline2])
   CSV.write("results/data_pattern_off.csv", df_off, append = true)

   df_on = DataFrame(ID = Int[], Service = Int64[], α = Float64[],
   Pattern = Int[], Day = Int[],
   Computing_time = Float64[], 
   Objective_online = Float64[], Objective_online1 = Float64[], Objective_online2 = Float64[], 
   Number_drivers = Float64[], FM_customers = Float64[], LM_customers = Float64[], D2D_customers = Float64[], 
   Dispatched_drivers = Float64[], Rejected_customers = Float64[], Canceled_customers = Float64[], Potential_demand = Int[], 
   Service_rate = Float64[], FM_rate = Float64[], LM_rate = Float64[])
   
   for (i, (s,)) in collect(enumerate(Iterators.product(set_service)))
     N_D = zeros(T+1, I)  #drivers 
     N_D[1,:] = N_drivers[:, Day] #drivers available
     N_F = zeros(T, J) #FM customers in transit.
     #println("Service: ", s[1])
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
     
     CSV.write("solutions/pattern/" * string(id) * "/x_stoch_" * string(service) * "_" * string(α) * ".csv", x)
     CSV.write("solutions/pattern/" * string(id) * "/y_stoch_" * string(service) * "_" * string(α) * ".csv", y)
     CSV.write("solutions/pattern/" * string(id) * "/z_stoch_" * string(service) * "_" * string(α) * ".csv", z)
     CSV.write("solutions/pattern/" * string(id) * "/v_stoch_" * string(service) * "_" * string(α) * ".csv", v)
     CSV.write("solutions/pattern/" * string(id) * "/w_stoch_" * string(service) * "_" * string(α) * ".csv", w)
     NPZ.npzwrite("solutions/pattern/" * string(id) * "/N_stoch_" * string(service) * "_" * string(α) * ".npz", N)
     NPZ.npzwrite("solutions/pattern/" * string(id) * "/F_stoch_" * string(service) * "_" * string(α) * ".npz", F)

     push!(df_on, [id, service, α, Pattern, Day, 
     Computing_time/T_horizon, Objective_online, Objective_online1, Objective_online2,
     Number_drivers, FM_customers, LM_customers, D2D_customers, 
     Dispatched_drivers, Rejected_customers, Canceled_customers, Potential_demand, Service_rate, FM_rate, LM_rate])
   end
   CSV.write("results/data_pattern_on.csv", df_on, append = true)
   return nothing  
end

RunSimulations(id, Pattern, Day)