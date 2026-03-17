using Distributed
using Statistics
#addprocs(3)
#@everywhere
#@everywhere
#@everywhere

#cd("C:\\Users\\thoma\\OneDrive\\Desktop\\PhD\\Output\\Papier 3 - Numerical Experiments/") 

include("Functions_Base.jl")
include("Data_Loading_Base.jl")

function RunSimulations(id::Int64, Demand::Float64, Supply::Float64, Day::Int64)

   #Simulation global parameters
   set_S = [10]
   set_R = [1, 2, 4, 8, 16]

   #Set initial states
   N_D = zeros(T+1, I)  #drivers 
   N_D[1,:] = N_drivers[:, Day] #drivers available
   N_F = zeros(T, J) #FM customers in transit.

   objective_offline = RunOffline(T_offline, N_D, N_F, D_test)
   #objective_offline = 1.0

   df_4 = DataFrame(ID = Int[], EVP = Bool[], Myopic = Bool[], S = Int[], Max_DRoutes = Int[], Demand = Float64[], Supply = Float64[], Day = Int[],
   Computing_time = Float64[], Empirical_ratio = Float64[], 
   Number_drivers = Float64[], FM_customers = Float64[], LM_customers = Float64[], D2D_customers = Float64[], 
   Dispatched_drivers = Float64[], Rejected_customers = Float64[], Potential_demand = Int[], Service_rate = Float64[], FM_rate = Float64[], LM_rate = Float64[])

   for (i, (s, dr)) in collect(enumerate(Iterators.product(set_S, set_R)))
      evp = true
      myopic = false

      N_D = zeros(T+1, I)  #drivers 
      N_D[1,:] = N_drivers[:, Day] #drivers available
      N_F = zeros(T, J) #FM customers in transit.

      S = s
      Q = 7
      Max_DispatchingRoutesPerCust = dr #dispatching routes

      Computing_time = @elapsed begin
         x, y, z, w, N, F, Dispatched_drivers, FM_customers, LM_customers, D2D_customers, Rejected_customers, objective_online = RunExpected(T_horizon, Max_DispatchingRoutesPerCust, S, Q, N_D, N_F, D_test, D_train)
      end 

      wait = rand(1:120)
      sleep(wait)
      println(FM_customers, " - ", LM_customers, " - ", D2D_customers, " - ", Dispatched_drivers)
      Potential_demand = sum(D_test[1:T_horizon, :])
      Empirical_ratio = objective_online/objective_offline
      Service_rate = (FM_customers + LM_customers + D2D_customers)./Potential_demand
      FM_rate = (FM_customers)/(FM_customers + LM_customers + D2D_customers)
      LM_rate = (LM_customers)/(FM_customers + LM_customers + D2D_customers)
      Number_drivers = sum(N_drivers[:, Day])
      
      push!(df_4, [id, evp, myopic, S, Max_DispatchingRoutesPerCust, Demand, Supply, Day, 
      Computing_time/T_horizon, Empirical_ratio,
      Number_drivers, FM_customers, LM_customers, D2D_customers, 
      Dispatched_drivers, Rejected_customers, Potential_demand, Service_rate, FM_rate, LM_rate])
   end
   CSV.write("results/data_base_4.csv", df_4, append = true)
   return nothing  
end

RunSimulations(id, Demand, Supply, Day)