using Distributed
using Statistics

cd("C:\\Users\\thoma\\OneDrive\\Desktop\\PhD\\Output\\Papier 3 - Numerical Experiments/") 

include("Functions_NYC.jl")
include("Data_Loading_NYC.jl")

function RunSimulations(id::Int64, Day::Int64, Q::Int64, delta::Float64, alpha::Float64)

   #Simulation global parameters
   set_service = [1]
   α = alpha
   tolerance = 0.05
   #wait = rand(1:60)
   #sleep(wait)
   #Set initial states
   N_D = zeros(T+1, I)  #drivers 
   N_D[1,:] = N_drivers[:, Day] #drivers available
   N_F = zeros(T, J) #FM customers in transit.
   Computing_time = @elapsed begin
     Objective_offline, Objective_offline1, Objective_offline2 = RunOffline(T_offline, N_D, N_F, D_test, N_test, α, delta)
   end 
   
   #objective_offline = 1.0

   df_off = DataFrame(ID = Int[], Day = Int[], delta = Float64[], alpha = Float64[],
   Computing_time = Float64[], 
   Objective_offline = Float64[], Objective_offline1 = Float64[], Objective_offline2 = Float64[])

   push!(df_off, [id, Day, delta, α, Computing_time, Objective_offline, Objective_offline1, Objective_offline2])
   CSV.write("results/data_NYC_off_delta.csv", df_off, append = true)

   df_on = DataFrame(ID = Int[], Service = Int64[], Day = Int[], Q = Int[], S = Int[], tolerance = Float64[], delta = Float64[], alpha = Float64[],
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
     Max_DispatchingRoutesPerCust = 8 #dispatching routes
     l_shaped = true

     Computing_time = @elapsed begin
       x, y, z, v, w, N, F, Dispatched_drivers, FM_customers, LM_customers, D2D_customers, Rejected_customers, Canceled_customers,
        Objective_online, Objective_online1, Objective_online2 = RunOnline(T_horizon, Max_DispatchingRoutesPerCust, S, Q, N_D, N_F, D_test, D_train, N_test, N_train, l_shaped, service, α, delta)
        #Objective_online, Objective_online1, Objective_online2 = RunExpected(T_horizon, Max_DispatchingRoutesPerCust, S, Q, N_D, N_F, D_test, D_train, l_shaped, service, α, delta)
     end 

     Potential_demand = sum(D_test[1:T_horizon, :])
     Service_rate = (FM_customers + LM_customers + D2D_customers)./Potential_demand
     FM_rate = (FM_customers)/(FM_customers + LM_customers + D2D_customers)
     LM_rate = (LM_customers)/(FM_customers + LM_customers + D2D_customers)
     Number_drivers = sum(N_drivers[:, Day])
     
     if Q == 8 && (delta == 0.5 || delta ==1.0 || delta == 0.2)
        CSV.write("solutions/NYC/" * string(Day) * "/x_stoch_" * string(service) * "_" * string(alpha) * "_" * string(delta) * ".csv", x)
        CSV.write("solutions/NYC/" * string(Day) * "/y_stoch_" * string(service) * "_" * string(alpha) * "_" * string(delta) * ".csv", y)
        CSV.write("solutions/NYC/" * string(Day) * "/z_stoch_" * string(service) * "_" * string(alpha) * "_" * string(delta) * ".csv", z)
        CSV.write("solutions/NYC/" * string(Day) * "/v_stoch_" * string(service) * "_" * string(alpha) * "_" * string(delta) * ".csv", v)
        CSV.write("solutions/NYC/" * string(Day) * "/w_stoch_" * string(service) * "_" * string(alpha) * "_" * string(delta) * ".csv", w)
        NPZ.npzwrite("solutions/NYC/" * string(Day) * "/N_stoch_" * string(service) * "_" * string(alpha) * "_" * string(delta) * ".npz", N)
        NPZ.npzwrite("solutions/NYC/" * string(Day) * "/F_stoch_" * string(service) * "_" * string(alpha) * "_" * string(delta) * ".npz", F)
     end

     push!(df_on, [id, service, Day,  Q, S, tolerance, delta, α,
     Computing_time/T_horizon, Objective_online, Objective_online1, Objective_online2,
     Number_drivers, FM_customers, LM_customers, D2D_customers, 
     Dispatched_drivers, Rejected_customers, Canceled_customers, Potential_demand, Service_rate, FM_rate, LM_rate])
   end
   CSV.write("results/data_NYC_on_delta.csv", df_on, append = true)
   return nothing  
end

RunSimulations(id, Day, Q, delta, alpha)