using Gurobi
using JuMP
import LinearAlgebra
using StochasticPrograms

function build_initial_customer_type_sets(
    D_test::Array{Float64, 2}, 
    D_train::Array{Float64, 3},
    Q_t::Int64, 
    S::Int64, 
    )

    𝐽_initial = Vector{Set}(undef, Q_t) 

    for t in 1:Q_t
        𝐽_initial[t] = Set()
    end

    𝐽_initial[1] = Set(findall(D_test[1, :] .> 0))
    if Q_t > 1
        for t in 2:Q_t
            for s in 1:S
                set_j = Set(findall(D_train[t, :, s] .> 0))
                𝐽_initial[t] = union(𝐽_initial[t], set_j)
            end
        end
    else 
        nothing
    end

    return 𝐽_initial
end

function build_initial_fm_route_sets(
    Min_ServiceT::Float64, 
    Max_AdditionalT::Float64, 
    Min_Reduction::Float64, 
    𝐽_initial::Vector{Set}, 
    ServiceT::Vector{Float64}, 
    origin::Vector{Int32}, 
    transfer_FM::Matrix{Int32}, 
    FT_bis::Matrix{Float64}, 
    DR_bis::Matrix{Float64}, 
    Q_t::Int64)

    𝐹_customer = Dict() 
    
    for t in 1:Q_t
        for j in 𝐽_initial[t]
            push!(𝐹_customer, (t, j) => Set())
        end
    end

    for t in 1:Q_t
        for j in 𝐽_initial[t] 
            if ServiceT[j] >= Min_ServiceT
                for i in 1:I 
                    if i != origin[j] 
                        j′ = transfer_FM[j, i] 
                        if FT_bis[j, i] <= 1000 #why
                            t′ = t + Int(floor(FT_bis[j, i])) + 1
                            if t′ <= Q_t
                                if ServiceT[j′] + FT_bis[j, i] <= ServiceT[j] * (1 + Max_AdditionalT) 
                                    if maximum(DR_bis[:, j′]) <= maximum(DR_bis[:, j]) - Min_Reduction
                                        idx = (j, i)
                                        push!(𝐹_customer[t, j], idx)
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    #for t in 1:Q_t
        #for j in 𝐽_initial[t] 
            #new_types_𝐹_customer = transfer_FM[CartesianIndex.(𝐹_customer[t, j])]
            #FT_𝐹_customer = get.([FT], 𝐹_customer[t, j], "na")
            #t′ = t .+ Int.(floor.(FT_𝐹_customer)) .+ 1
            #NDR_𝐹_customer = LinearAlgebra.diag(DR_bis[t′, new_types_𝐹_customer])
            #order = sortperm(NDR_𝐹_customer, rev=false)
            #𝐹_customer[t, j] = 𝐹_customer[t, j][order]
            #𝐹_customer[t, j] = 𝐹_customer[t, j][1:min(Max_FMRoutesPerCust,end)]
            #𝐹_customer[t, j] = Set(𝐹_customer[t, j])
        #end
    #end

    𝐹 = Vector{Set}(undef, Q_t) 

    for t in 1:Q_t
        𝐹[t] = Set()
        for j in 𝐽_initial[t]
            𝐹[t] = union(𝐹[t], 𝐹_customer[t, j])
        end
    end
    return (𝐹, 𝐹_customer)
end

function build_initial_lm_route_sets(
    Min_ServiceT::Float64, 
    Max_AdditionalT::Float64, 
    Min_Reduction::Float64, 
    𝐽_initial::Vector{Set}, 
    ServiceT::Vector{Float64}, 
    destination::Vector{Int32}, 
    transfer_LM::Matrix{Int32}, 
    LT_bis::Matrix{Float64}, 
    DR_bis::Matrix{Float64},
    Q_t::Int64)

    𝐿_customer = Dict() 

    for t in 1:Q_t
        for j in 𝐽_initial[t]
            push!(𝐿_customer, (t, j) => Set())
        end
    end

    for t in 1:Q_t
        for j in 𝐽_initial[t] 
            for i in 1:I 
                if i == destination[j]
                    idx = (j, i)
                    push!(𝐿_customer[t, j], idx)
                else 
                    if ServiceT[j] >= Min_ServiceT
                        j′ = transfer_LM[j, i] 
                        if ServiceT[j′] + LT_bis[j, i]<= (1 + Max_AdditionalT) * ServiceT[j] 
                            if maximum(DR_bis[:, j′]) <=  maximum(DR_bis[:, j]) - Min_Reduction
                                idx = (j, i)
                                push!(𝐿_customer[t, j], idx)
                            end
                        end
                    end
                end
            end
        end
    end
    
    #LT = Dict()
    #for t in 1:Q_t
    #    for j in 𝐽_initial[t] 
    #        for l in 𝐿_customer[t, j]
    #            push!(LT, l => LT_bis[l[1], l[2]])
    #        end
    #    end
    #end

    #for t in 1:Q_t
    #    for j in 𝐽_initial[t] 
            #new_types_𝐿_customer = transfer_LM[CartesianIndex.(𝐿_customer[t, j])]
            #idx = findall(x -> x == j, new_types_𝐿_customer)[1]
            #NDR_𝐿_customer = DR_bis[t, new_types_𝐿_customer]
            #order = sortperm(NDR_𝐿_customer, rev = true) #rev=false : ascending order
            #idx_in_order = findall(x->x == idx, order)[1]
            #order_bis = zeros(Int, length(order))
            #for i in length(order):-1:1
            #    if i > idx_in_order
            #        order_bis[i] = order[i]
            #    elseif i == idx_in_order && (i > 1)
            #        order_bis[i] = order[i-1]
            #    elseif (i < idx_in_order) && (i > 1)
            #        order_bis[i] = order[i-1]
            #    elseif i==1
            #        order_bis[i] = idx
            #    end
            #end
            #𝐿_customer[t, j] = 𝐿_customer[t, j][order_bis]
            #𝐿_customer[t, j] = 𝐿_customer[t, j][1:min(Max_LMRoutesPerCust, end)]
    #        𝐿_customer[t, j] = Set(𝐿_customer[t, j])
    #    end
    #end 
    
    𝐿 = Vector{Set}(undef, Q_t) 

    for t in 1:Q_t
        𝐿[t] = Set()
        for j in 𝐽_initial[t]
            #if j == 2241
            #    println(t, " - ", j, " : ", 𝐿_customer[t, j])
            #end
            𝐿[t] = union(𝐿[t], 𝐿_customer[t, j])
        end
    end

    return (𝐿, 𝐿_customer)
end

function build_initial_d2d_route_sets(
    Min_ServiceT::Float64, 
    Max_AdditionalT::Float64, 
    Min_Reduction::Float64, 
    𝐽_initial::Vector{Set}, 
    ServiceT::Vector{Float64}, 
    destination::Vector{Int32}, 
    transfer_LM::Matrix{Int32}, 
    LT_bis::Matrix{Float64}, 
    #DR_bis::Matrix{Float64},
    Q_t::Int64)

    𝐿_customer = Dict() 

    for t in 1:Q_t
        for j in 𝐽_initial[t]
            push!(𝐿_customer, (t, j) => Set())
        end
    end

    for t in 1:Q_t
        for j in 𝐽_initial[t] 
            for i in 1:I 
                if i == destination[j]
                    idx = (j, i)
                    push!(𝐿_customer[t, j], idx)
                else
                    nothing
                end
            end
        end
    end
    
    𝐿 = Vector{Set}(undef, Q_t) 

    for t in 1:Q_t
        𝐿[t] = Set()
        for j in 𝐽_initial[t]
            𝐿[t] = union(𝐿[t], 𝐿_customer[t, j])
        end
    end
    return (𝐿, 𝐿_customer)
end

function build_final_customer_type_sets(
    𝐹::Vector{Set},
    transfer_FM::Matrix{Int32}, 
    FT_bis::Matrix{Float64}, 
    𝐿::Vector{Set}, 
    transfer_LM::Matrix{Int32}, 
    N_F_t::Matrix{Float64},
    Q_t::Int64)

    𝐽 = Vector{Set}(undef, Q_t) 

    # First mile types from previous epochs
    for t in 1:Q_t
        𝐽[t] = Set(findall(N_F_t[t, :] .> 0))
    end 

    # Last-mile types
    for t in 1:Q_t
        for idx in 𝐿[t]
            j′ = transfer_LM[idx[1], idx[2]]
            push!(𝐽[t], j′)
        end
    end

    # First-mile types now 
    for t in 1:Q_t
        for idx in 𝐹[t]
            j′ = transfer_FM[idx[1], idx[2]]
            t′ = t + Int(floor(FT_bis[idx[1], idx[2]])) + 1
            if t′ <= Q_t
                push!(𝐽[t′], j′)
            end
        end
    end    
    return 𝐽
end

function build_final_fm_route_sets(
    𝐽::Vector{Set}, 
    𝐹::Vector{Set},  
    transfer_FM::Matrix{Int32}, 
    Q_t::Int64)

    𝐹_overline = Dict() 
    
    for t in 1:Q_t
        for j in 𝐽[t]
            for k in 1:t
                push!(𝐹_overline, (k, j) => Set())
            end
        end
    end

    for t in 1:Q_t
        for f in 𝐹[t]
            j = transfer_FM[f[1], f[2]]
            push!(𝐹_overline[t, j], f)
        end
    end
    return 𝐹_overline
end

function build_final_lm_route_sets(
    𝐽::Vector{Set},
    𝐿::Vector{Set},  
    transfer_LM::Matrix{Int32}, 
    Q_t::Int64)

    𝐿_overline = Dict()

    for t in 1:Q_t
        for j in 𝐽[t]
            push!(𝐿_overline, (t, j) => Set())
        end
    end

    for t in 1:Q_t
        for idx in 𝐿[t]
            j = transfer_LM[idx[1], idx[2]]
            push!(𝐿_overline[t, j], idx)
        end
    end
    return 𝐿_overline
end

function build_dispatching_route_sets(
    Max_DispatchingRoutesPerCust::Int64,
    𝐽::Vector{Set}, 
    PickupT::Matrix{Float64}, 
    destination::Vector{Int32}, 
    N_D_t::Matrix{Float64},
    Q_t::Int64, 
    I::Int64)

    𝑅_customer = Dict() 
    for t in 1:Q_t
        for j in 𝐽[t]
            push!(𝑅_customer, (t, j) => [])
        end
    end
    
    for j in 𝐽[1] 
        for i in 1:I 
            if N_D_t[1, i] > 0.0
                idx = (i, j) 
                push!(𝑅_customer[1, j], idx) 
            end
        end 
    end

    for j in 𝐽[1]
        feasible_pickup = []
        for i in 1:I 
            if N_D_t[1, i] > 0.0
                push!(feasible_pickup, PickupT[i, j])
            end
        end
        order = sortperm(feasible_pickup)
        𝑅_customer[1, j] = 𝑅_customer[1, j][order]
        𝑅_customer[1, j] = 𝑅_customer[1, j][1:min(Max_DispatchingRoutesPerCust, end)]            
        𝑅_customer[1, j] = Set(𝑅_customer[1, j])
        #for i in 1:I 
        #    if PickupT[i, j] > Max_PickupT 
        #        idx = (i, j)
        #        delete!(𝑅_customer[1, j], idx)
        #    end
        #end
    end

    if Q_t >= 2
        for t in 2:Q_t
            for i in 1:I 
                for j in 𝐽[t] 
                    idx = (i, j) 
                    push!(𝑅_customer[t, j], idx) 
                end 
            end
        end
    
        for t in 2:Q_t
            for j in 𝐽[t] 
                order = sortperm(PickupT[:, j])
                𝑅_customer[t, j] = 𝑅_customer[t, j][order]
                𝑅_customer[t, j] = 𝑅_customer[t, j][1:min(Max_DispatchingRoutesPerCust, end)]
                𝑅_customer[t, j] = Set(𝑅_customer[t, j])
                #for i in 1:I 
                    #if PickupT[i, j] > Max_PickupT 
                    #    idx = (i, j)
                    #    delete!(𝑅_customer[t, j], idx)
                    #end
                #end
            end
        end
    end

    
    𝑅 = Vector{Set}(undef, Q_t) 

    for t in 1:Q_t
        𝑅[t] = Set()
        for j in 𝐽[t]
            𝑅[t] = union(𝑅[t], 𝑅_customer[t, j])
        end
    end

    𝑂 = Array{Set}(undef, (Q_t, I))

    for t in 1:Q_t
        for i in 1:I
            𝑂[t, i] = Set() 
        end
    end
    
    for t in 1:Q_t
        for idx in 𝑅[t]
            i = idx[1]
            push!(𝑂[t, i], idx)
        end
    end

    𝐷 = Array{Set}(undef, (Q_t, I)) 

    for t in 1:Q_t
        for i in 1:I
            𝐷[t, i] = Set() 
        end
    end

    for t in 1:Q_t
        for idx in 𝑅[t]
            i = destination[idx[2]]
            push!(𝐷[t, i], idx)
        end
    end
    return (𝑅, 𝑅_customer, 𝑂, 𝐷)
end

function build_dictionaries(
    𝐽::Vector{Set},
    𝐽_initial::Vector{Set},
    𝑅::Vector{Set},
    𝐿::Vector{Set},
    𝐹::Vector{Set},
    DR_bis::Matrix{Float64},
    LC_bis::Matrix{Float64},
    FC_bis::Matrix{Float64},
    DT_bis::Matrix{Float64},
    LT_bis::Matrix{Float64},
    FT_bis::Matrix{Float64},
    RT_bis::Vector{Float64},
    Q_t::Int64
    )

    DT = Dict()
    for t in 1:Q_t
        for r in 𝑅[t]
            push!(DT, r => DT_bis[r[1], r[2]])
        end
    end

    DR = Dict()
    for t in 1:Q_t
        for r in 𝑅[t]
            push!(DR, (t, r) => DR_bis[r[1], r[2]])
        end
    end

    FT = Dict()
    for t in 1:Q_t
        for f in 𝐹[t]
            push!(FT, f => FT_bis[f[1], f[2]])
        end
    end

    LT = Dict()
    for t in 1:Q_t
        for l in 𝐿[t]
            push!(LT, l => LT_bis[l[1], l[2]])
        end
    end

    LC = Dict()
    for t in 1:Q_t
        for l in 𝐿[t]
            push!(LC, l => LC_bis[l[1], l[2]])
        end
    end

    FC = Dict()
    for t in 1:Q_t
        for f in 𝐹[t]
            push!(FC, f => FC_bis[f[1], f[2]])
            #push!(FC, f => 0.5)
        end
    end

    RT_1 = Dict()
    for t in 1:Q_t
        for j in 𝐽_initial[t]
            push!(RT_1, j => RT_bis[j])
        end
    end

    RT_2 = Dict()
    for t in 1:Q_t
        for j in 𝐽[t]
            push!(RT_2, j => RT_bis[j] + 2.0)
        end
    end

    RC = Dict()
    for t in 1:Q_t
        for j in 𝐽[t]
            push!(RC, (t, j) => -maximum(DR_bis[:, j]))
        end
    end
    return (DR, LC, FC, RC, DT, LT, FT, RT_1, RT_2)
end

function formulate_and_solve_optimization_problem(
    𝐽_initial::Vector{Set}, 
    𝐽::Vector{Set}, 
    𝑅::Vector{Set}, 
    𝑅_customer::Dict{Any, Any}, 
    𝑂::Matrix{Set}, 
    𝐷::Matrix{Set}, 
    𝐹::Vector{Set}, 
    𝐹_customer::Dict{Any, Any}, 
    𝐹_overline::Dict{Any, Any}, 
    𝐿::Vector{Set}, 
    𝐿_customer::Dict{Any, Any}, 
    𝐿_overline::Dict{Any, Any},
    D_t::Matrix{Float64},
    D_train::Array{Float64, 3}, 
    N_D_t::Matrix{Float64},
    N_F_t::Matrix{Float64}, 
    DR::Dict{Any, Any}, 
    FC::Dict{Any, Any},
    LC::Dict{Any, Any},
    RC::Dict{Any, Any},
    DT::Dict{Any, Any},
    FT::Dict{Any, Any},
    LT::Dict{Any, Any},
    RT_1::Dict{Any, Any},
    RT_2::Dict{Any, Any},
    S::Int64,
    Q_t::Int64,
    I::Int64,
    l_shaped::Bool,
    offline::Bool,
    α::Float64)

    #println("Set of J[1]", 𝐽_initial[1])
    #println("Set of J[2]", 𝐽_initial[2])
    #println("Set of L", 𝐿[1])
    #for k in keys(𝐿_overline)
    #    if k[1] == 1
    #        println("Set of L_overline with", k[2]," : ", 𝐿_overline[k])
    #    end
    #end
    #for k in keys(𝐿_customer)
    #    if k[1] == 1
    #        println("Set of L_customer with", k[2]," : ", 𝐿_overline[k])
    #    end
    #end
    #println("Set of L", 𝐿[1])
    #println("Set of L", 𝐿[1])
    #println("Set of R", 𝑅[1])
    #for k in keys(𝑅_customer)
    #    if k[1] == 1
    #        println("Set of R_customer with ", k[2]," : ", 𝑅_customer[k])
    #    end
    #end
    #for i in 1:I
    #    println("Number of drivers in ", i," : ", N_D_t[1, i])
    #end

    function δ(t, t′, r)
        if t + floor(DT[r]) + 1 == t′
            return true
        else
            return false
        end
    end
    
    function ϵ(t, t′, f)
        if t + floor(FT[f]) + 1 == t′
            return true
        else
            return false
        end
    end

    if Q_t == 1 
        problem = Model(Gurobi.Optimizer)
        set_silent(problem)
        set_optimizer_attribute(problem, "TimeLimit", 600)

        @variable(problem, x1[𝑅[1]], Int) 
        @variable(problem, z1[𝐿[1]], Int)
        @variable(problem, v1[𝐽_initial[1]], Int)
        @variable(problem, w1[𝐽[1]] >= 0)
        @constraint(problem, nonneg1[r in 𝑅[1]], x1[r] >= 0)
        @constraint(problem, nonneg3[l in 𝐿[1]], z1[l] >= 0)
        @constraint(problem, nonneg4[j in 𝐽_initial[1]], v1[j] >= 0)
        #@constraint(problem, nonneg4[j in 𝐽[1]], w1[j] >= 0)
        @constraint(problem, directing[j in 𝐽_initial[1]], sum(z1[l] for l in 𝐿_customer[1, j]) + v1[j] == D_t[1, j])
        @constraint(problem, satisfy_demand1[j in 𝐽[1]], sum(x1[r] for r in 𝑅_customer[1, j]) + w1[j] == round(N_F_t[1, j]) + sum(z1[l] for l in 𝐿_overline[1, j]))
        @constraint(problem, supply_conservation1[i in 1:I], sum(x1[r] for r in 𝑂[1, i]) <= N_D_t[1, i])
        @objective(problem, Max, sum((α * DR[1, r] + (1-α) * -DT[r]) * x1[r] for r in 𝑅[1]) + sum((α * LC[l] + (1-α) * -LT[l]) * z1[l] for l in 𝐿[1]) + sum((α * 0.0 + (1-α) * -RT_1[j]) * v1[j] for j in 𝐽_initial[1]) + sum((α * RC[1, j] + (1-α) * -RT_2[j]) * w1[j] for j in 𝐽[1]))

        optimize!(problem)
        x1 = value.(problem[:x1])
        y1 = zeros(I^2)
        z1 = value.(problem[:z1])
        v1 = value.(problem[:v1])
        w1 = value.(problem[:w1])

        obj_value_first_period = sum((α * DR[1, r] + (1-α) * -DT[r]) * x1[r] for r in 𝑅[1]; init=0.0) + sum((α * LC[l] + (1-α) * -LT[l]) * z1[l] for l in 𝐿[1]; init=0.0) + sum((α * 0.0 + (1-α) * -RT_1[j]) * v1[j] for j in 𝐽_initial[1]; init=0.0) + sum((α * RC[1, j] + (1-α) * -RT_2[j]) * w1[j] for j in 𝐽[1]; init=0.0)
        obj_value1_first_period = sum(DR[1, r] * x1[r] for r in 𝑅[1]; init=0.0) + sum(LC[l] * z1[l] for l in 𝐿[1]; init=0.0) + sum(0.0 * v1[j] for j in 𝐽_initial[1]; init=0.0) + sum(RC[1, j] * w1[j] for j in 𝐽[1]; init=0.0)
        obj_value2_first_period = sum(-DT[r] * x1[r] for r in 𝑅[1]; init=0.0) + sum(-LT[l] * z1[l] for l in 𝐿[1]; init=0.0) + sum(-RT_1[j] * v1[j] for j in 𝐽_initial[1]; init=0.0) + sum(-RT_2[j] * w1[j] for j in 𝐽[1]; init=0.0)

        obj_value = objective_value(problem)

        return (
        x1, 
        y1, 
        z1,
        v1,
        w1,
        obj_value_first_period,
        obj_value1_first_period,
        obj_value2_first_period,
        obj_value)

    else
        if Q_t == 2
            @stochastic_model model begin
                @stage 1 begin
                    @decision(model, x1[𝑅[1]], Int)
                    @decision(model, z1[𝐿[1]], Int)
                    @decision(model, v1[𝐽_initial[1]], Int)
                    @decision(model, w1[𝐽[1]] >= 0)
                    @constraint(model, nonneg1[r in 𝑅[1]], x1[r] >= 0)
                    @constraint(model, nonneg3[l in 𝐿[1]], z1[l] >= 0)
                    @constraint(model, nonneg4[j in 𝐽_initial[1]], v1[j] >= 0)
                    #@constraint(model, nonneg4[j in 𝐽[1]], w1[j] >= 0)
                    @constraint(model, directing1[j in 𝐽_initial[1]], sum(z1[l] for l in 𝐿_customer[1, j]) + v1[j] == D_t[1, j])
                    @constraint(model, satisfy_demand1[j in 𝐽[1]], sum(x1[r] for r in 𝑅_customer[1, j]) + w1[j] == round(N_F_t[1, j]) + sum(z1[l] for l in 𝐿_overline[1, j]))
                    @constraint(model, supply_conservation1[i in 1:I], sum(x1[r] for r in 𝑂[1, i]) <= N_D_t[1, i])
                    @objective(model, Max, sum((α * DR[1, r] + (1-α) * -DT[r]) * x1[r] for r in 𝑅[1]) + sum((α * LC[l] + (1-α) * -LT[l]) * z1[l] for l in 𝐿[1]) + sum((α * 0.0 + (1-α) * -RT_1[j]) * v1[j] for j in 𝐽_initial[1]) + sum((α * RC[1, j] + (1-α) * -RT_2[j]) * w1[j] for j in 𝐽[1]))
                end
                @stage 2 begin
                    @uncertain D_stoch 
                    @recourse(model, x[t in 2:Q_t, 𝑅[t]] >= 0)
                    @recourse(model, z[t in 2:Q_t, 𝐿[t]] >= 0)
                    @recourse(model, v[t in 2:Q_t, 𝐽_initial[t]] >= 0)
                    @recourse(model, w[t in 2:Q_t, 𝐽[t]] >= 0)
                    @objective(model, Max, sum((α * DR[t, r] + (1-α) * -DT[r]) * x[t, r] for t in 2:Q_t for r in 𝑅[t]) + sum((α * LC[l] + (1-α) * -LT[l]) * z[t, l] for t in 2:Q_t for l in 𝐿[t]) + sum((α * 0.0 + (1-α) * -RT_1[j]) * v[t, j] for t in 2:Q_t for j in 𝐽_initial[t]) + sum((α * RC[t, j] + (1-α) * -RT_2[j]) * w[t, j] for t in 2:Q_t for j in 𝐽[t]))     
                    @constraint(model, directing[t in 2:Q_t, j in 𝐽_initial[t]], sum(z[t, l] for l in 𝐿_customer[t, j]) + v[t, j] == D_stoch[t, j])
                    @constraint(model, satisfy_demand2[j in 𝐽[2]], sum(x[2, r] for r in 𝑅_customer[2, j]) + w[2, j] == round(N_F_t[2, j]) + sum(z[2, l] for l in 𝐿_overline[2, j]))  
                    @constraint(model, supply_conservation2[i in 1:I], sum(x1[r] for r in 𝑂[1, i]) + sum(x[2, r] for r in 𝑂[2, i]) <= sum(N_D_t[u, i] for u in 1:2) + sum(x1[r] * δ(1, 2, r) for r in 𝐷[1, i]))
                end    
            end
        else    
            if isempty(𝐹[1]) == false && all(isequal(Set()), 𝐹[2:end]) == false
                #println(isempty(𝐹[1]), " - ", all(isequal(Set()), 𝐹[2:end]))
                @stochastic_model model begin
                    @stage 1 begin
                        @decision(model, x1[𝑅[1]], Int)
                        @decision(model, y1[𝐹[1]], Int)
                        @decision(model, z1[𝐿[1]], Int)
                        @decision(model, v1[𝐽_initial[1]], Int)
                        @decision(model, w1[𝐽[1]] >= 0)
                        @constraint(model, nonneg1[r in 𝑅[1]], x1[r] >= 0)
                        @constraint(model, nonneg2[f in 𝐹[1]], y1[f] >= 0)
                        @constraint(model, nonneg3[l in 𝐿[1]], z1[l] >= 0)
                        @constraint(model, nonneg4[j in 𝐽_initial[1]], v1[j] >= 0)
                        #@constraint(model, nonneg4[j in 𝐽[1]], w1[j] >= 0)
                        @constraint(model, directing1[j in 𝐽_initial[1]], sum(y1[f] for f in 𝐹_customer[1, j]) + sum(z1[l] for l in 𝐿_customer[1, j]) + v1[j] == D_t[1, j])
                        @constraint(model, satisfy_demand1[j in 𝐽[1]], sum(x1[r] for r in 𝑅_customer[1, j]) + w1[j] == round(N_F_t[1, j]) + sum(z1[l] for l in 𝐿_overline[1, j]))
                        @constraint(model, supply_conservation1[i in 1:I], sum(x1[r] for r in 𝑂[1, i]) <= N_D_t[1, i])
                        @objective(model, Max, sum((α * DR[1, r] + (1-α) * -DT[r])* x1[r] for r in 𝑅[1]) + sum((α * FC[f] + (1 - α) * -FT[f]) * y1[f] for f in 𝐹[1]) + sum((α * LC[l] + (1-α) * -LT[l]) * z1[l] for l in 𝐿[1]) + sum((α * 0.0 + (1-α) * -RT_1[j]) * v1[j] for j in 𝐽_initial[1]) + sum((α * RC[1, j] + (1-α) * -RT_2[j]) * w1[j] for j in 𝐽[1]))
                    end
                    @stage 2 begin
                        @uncertain D_stoch 
                        @recourse(model, x[t in 2:Q_t, 𝑅[t]] >= 0)
                        @recourse(model, y[t in 2:Q_t, 𝐹[t]] >= 0)
                        @recourse(model, z[t in 2:Q_t, 𝐿[t]] >= 0)
                        @recourse(model, v[t in 2:Q_t, 𝐽_initial[t]] >= 0)
                        @recourse(model, w[t in 2:Q_t, 𝐽[t]] >= 0)
                        @objective(model, Max, sum((α * DR[t, r] + (1-α) * -DT[r]) * x[t, r] for t in 2:Q_t for r in 𝑅[t]) +  sum((α * FC[f] + (1 - α) * -FT[f]) * y[t, f] for t in 2:Q_t for f in 𝐹[t]) + sum((α * LC[l] + (1-α) * -LT[l]) * z[t, l] for t in 2:Q_t for l in 𝐿[t]) + sum((α * 0.0 + (1-α) * -RT_1[j]) * v[t, j] for t in 2:Q_t for j in 𝐽_initial[t]) + sum((α * RC[t, j] + (1-α) * -RT_2[j]) * w[t, j] for t in 2:Q_t for j in 𝐽[t]))     
                        @constraint(model, directing[t in 2:Q_t, j in 𝐽_initial[t]], sum(y[t, f] for f in 𝐹_customer[t, j]) + sum(z[t, l] for l in 𝐿_customer[t, j]) + v[t, j] == D_stoch[t, j])
                        @constraint(model, satisfy_demand2[j in 𝐽[2]], sum(x[2, r] for r in 𝑅_customer[2, j]) + w[2, j] == 
                        round(N_F_t[2, j]) + sum(y1[f] * ϵ(1, 2, f) for f in 𝐹_overline[1, j]) + sum(z[2, l] for l in 𝐿_overline[2, j]))  
                        @constraint(model, satisfy_demand[t in 3:Q_t, j in 𝐽[t]], sum(x[t, r] for r in 𝑅_customer[t, j]) + w[t, j] == 
                        round(N_F_t[t, j]) + sum(y1[f] * ϵ(1, t, f) for f in 𝐹_overline[1, j]) + sum(y[u, f] * ϵ(u, t, f) for u in 2:(t-1) for f in 𝐹_overline[u, j]) + sum(z[t, l] for l in 𝐿_overline[t, j]))
                        @constraint(model, supply_conservation2[i in 1:I], sum(x1[r] for r in 𝑂[1, i]) + sum(x[2, r] for r in 𝑂[2, i]) <= sum(N_D_t[u, i] for u in 1:2) + sum(x1[r] * δ(1, 2, r) for r in 𝐷[1, i]))
                        @constraint(model, supply_conservation[t in 3:Q_t, i in 1:I], sum(x1[r] for r in 𝑂[1, i]) + sum(x[u, r] for u in 2:t for r in 𝑂[u, i]) <= sum(N_D_t[u, i] for u in 1:t) + sum(x1[r] * δ(1, v, r) for v in 2:t for r in 𝐷[1, i]) + sum(x[u, r] * δ(u, v, r) for u in 2:(t-1) for v in (u+1):t for r in 𝐷[u, i]))
                    end    
                end  
            elseif  isempty(𝐹[1]) == true && all(isequal(Set()), 𝐹[2:end]) == true
                #println(isempty(𝐹[1]), " - ", all(isequal(Set()), 𝐹[2:end]))
                @stochastic_model model begin
                    @stage 1 begin
                        #@decision(model, x1[𝑅[1]], Int)
                        @decision(model, x1[𝑅[1]], Int)
                        @decision(model, z1[𝐿[1]], Int)
                        @decision(model, v1[𝐽_initial[1]], Int)
                        @decision(model, w1[𝐽[1]] >= 0)
                        @constraint(model, nonneg1[r in 𝑅[1]], x1[r] >= 0)
                        @constraint(model, nonneg3[l in 𝐿[1]], z1[l] >= 0)
                        @constraint(model, nonneg4[j in 𝐽_initial[1]], v1[j] >= 0)
                        #@constraint(model, nonneg4[j in 𝐽[1]], w1[j] >= 0)
                        @constraint(model, directing1[j in 𝐽_initial[1]], sum(z1[l] for l in 𝐿_customer[1, j]) + v1[j] == D_t[1, j])
                        @constraint(model, satisfy_demand1[j in 𝐽[1]], sum(x1[r] for r in 𝑅_customer[1, j]) + w1[j] == round(N_F_t[1, j]) + sum(z1[l] for l in 𝐿_overline[1, j]))
                        @constraint(model, supply_conservation1[i in 1:I], sum(x1[r] for r in 𝑂[1, i]) <= N_D_t[1, i])
                        @objective(model, Max, sum((α * DR[1, r] + (1-α) * -DT[r]) * x1[r] for r in 𝑅[1]) + sum((α * LC[l] + (1-α) * -LT[l]) * z1[l] for l in 𝐿[1]) + sum((α * 0.0 + (1-α) * -RT_1[j]) * v1[j] for j in 𝐽_initial[1]) + sum((α * RC[1, j] + (1-α) * -RT_2[j]) * w1[j] for j in 𝐽[1]))
                    end
                    @stage 2 begin
                        @uncertain D_stoch 
                        @recourse(model, x[t in 2:Q_t, 𝑅[t]] >= 0)
                        @recourse(model, z[t in 2:Q_t, 𝐿[t]] >= 0)
                        @recourse(model, v[t in 2:Q_t, 𝐽_initial[t]] >= 0)
                        @recourse(model, w[t in 2:Q_t, 𝐽[t]] >= 0)
                        @objective(model, Max, sum((α * DR[t, r] + (1-α) * -DT[r]) * x[t, r] for t in 2:Q_t for r in 𝑅[t]) + sum((α * LC[l] + (1-α) * -LT[l]) * z[t, l] for t in 2:Q_t for l in 𝐿[t]) + sum((α * 0.0 + (1-α) * -RT_1[j]) * v[t, j] for t in 2:Q_t for j in 𝐽_initial[t]) + sum((α * RC[t, j] + (1-α) * -RT_2[j]) * w[t, j] for t in 2:Q_t for j in 𝐽[t]))     
                        @constraint(model, directing[t in 2:Q_t, j in 𝐽_initial[t]], sum(z[t, l] for l in 𝐿_customer[t, j]) + v[t, j] == D_stoch[t, j])
                        @constraint(model, satisfy_demand2[j in 𝐽[2]], sum(x[2, r] for r in 𝑅_customer[2, j]) + w[2, j] == 
                        round(N_F_t[2, j]) + sum(z[2, l] for l in 𝐿_overline[2, j]))  
                        @constraint(model, satisfy_demand[t in 3:Q_t, j in 𝐽[t]], sum(x[t, r] for r in 𝑅_customer[t, j]) + w[t, j] == 
                        round(N_F_t[t, j]) + sum(z[t, l] for l in 𝐿_overline[t, j]))
                        @constraint(model, supply_conservation2[i in 1:I], sum(x1[r] for r in 𝑂[1, i]) + sum(x[2, r] for r in 𝑂[2, i]) <= sum(N_D_t[u, i] for u in 1:2) + sum(x1[r] * δ(1, 2, r) for r in 𝐷[1, i]))
                        @constraint(model, supply_conservation[t in 3:Q_t, i in 1:I], sum(x1[r] for r in 𝑂[1, i]) + sum(x[u, r] for u in 2:t for r in 𝑂[u, i]) <= sum(N_D_t[u, i] for u in 1:t) + sum(x1[r] * δ(1, v, r) for v in 2:t for r in 𝐷[1, i]) + sum(x[u, r] * δ(u, v, r) for u in 2:(t-1) for v in (u+1):t for r in 𝐷[u, i]))
                    end    
                end    
            elseif  isempty(𝐹[1]) == false && all(isequal(Set()), 𝐹[2:end]) == true
                #println(isempty(𝐹[1]), " - ", all(isequal(Set()), 𝐹[2:end]))
                @stochastic_model model begin
                    @stage 1 begin
                        #@decision(model, x1[𝑅[1]], Int)
                        @decision(model, x1[𝑅[1]], Int)
                        @decision(model, y1[𝐹[1]], Int)
                        @decision(model, z1[𝐿[1]], Int)
                        @decision(model, v1[𝐽_initial[1]], Int)
                        @decision(model, w1[𝐽[1]] >= 0)
                        @constraint(model, nonneg1[r in 𝑅[1]], x1[r] >= 0)
                        @constraint(model, nonneg2[f in 𝐹[1]], y1[f] >= 0)
                        @constraint(model, nonneg3[l in 𝐿[1]], z1[l] >= 0)
                        @constraint(model, nonneg4[j in 𝐽_initial[1]], v1[j] >= 0)
                        #@constraint(model, nonneg4[j in 𝐽[1]], w1[j] >= 0)
                        @constraint(model, directing1[j in 𝐽_initial[1]], sum(y1[f] for f in 𝐹_customer[1, j]) + sum(z1[l] for l in 𝐿_customer[1, j]) + v1[j] == D_t[1, j])
                        @constraint(model, satisfy_demand1[j in 𝐽[1]], sum(x1[r] for r in 𝑅_customer[1, j]) + w1[j] == round(N_F_t[1, j]) + sum(z1[l] for l in 𝐿_overline[1, j]))
                        @constraint(model, supply_conservation1[i in 1:I], sum(x1[r] for r in 𝑂[1, i]) <= N_D_t[1, i])
                        @objective(model, Max, sum((α * DR[1, r] + (1-α) * -DT[r]) * x1[r] for r in 𝑅[1]) + sum((α * FC[f] + (1 - α) * -FT[f]) * y1[f] for f in 𝐹[1]) + sum((α * LC[l] + (1-α) * -LT[l]) * z1[l] for l in 𝐿[1]) + sum((α * 0.0 + (1-α) * -RT_1[j]) * v1[j] for j in 𝐽_initial[1]) + sum((α * RC[1, j] + (1-α) * -RT_2[j]) * w1[j] for j in 𝐽[1]))
                    end
                    @stage 2 begin
                        @uncertain D_stoch 
                        @recourse(model, x[t in 2:Q_t, 𝑅[t]] >= 0)
                        @recourse(model, z[t in 2:Q_t, 𝐿[t]] >= 0)
                        @recourse(model, v[t in 2:Q_t, 𝐽_initial[t]] >= 0)
                        @recourse(model, w[t in 2:Q_t, 𝐽[t]] >= 0)
                        @objective(model, Max, sum((α * DR[t, r] + (1-α) * -DT[r]) * x[t, r] for t in 2:Q_t for r in 𝑅[t]) + sum((α * LC[l] + (1-α) * -LT[l]) * z[t, l] for t in 2:Q_t for l in 𝐿[t]) + sum((α * 0.0 + (1-α) * -RT_1[j]) * v[t, j] for t in 2:Q_t for j in 𝐽_initial[t]) + sum((α * RC[t, j] + (1-α) * -RT_2[j]) * w[t, j] for t in 2:Q_t for j in 𝐽[t]))     
                        @constraint(model, directing[t in 2:Q_t, j in 𝐽_initial[t]], sum(z[t, l] for l in 𝐿_customer[t, j]) + v[t, j] == D_stoch[t, j])
                        @constraint(model, satisfy_demand2[j in 𝐽[2]], sum(x[2, r] for r in 𝑅_customer[2, j]) + w[2, j] == 
                        round(N_F_t[2, j]) + sum(y1[f] * ϵ(1, 2, f) for f in 𝐹_overline[1, j]) + sum(z[2, l] for l in 𝐿_overline[2, j]))  
                        @constraint(model, satisfy_demand[t in 3:Q_t, j in 𝐽[t]], sum(x[t, r] for r in 𝑅_customer[t, j]) + w[t, j] == 
                        round(N_F_t[t, j]) + sum(y1[f] * ϵ(1, t, f) for f in 𝐹_overline[1, j]) + sum(z[t, l] for l in 𝐿_overline[t, j]))
                        @constraint(model, supply_conservation2[i in 1:I], sum(x1[r] for r in 𝑂[1, i]) + sum(x[2, r] for r in 𝑂[2, i]) <= sum(N_D_t[u, i] for u in 1:2) + sum(x1[r] * δ(1, 2, r) for r in 𝐷[1, i]))
                        @constraint(model, supply_conservation[t in 3:Q_t, i in 1:I], sum(x1[r] for r in 𝑂[1, i]) + sum(x[u, r] for u in 2:t for r in 𝑂[u, i]) <= sum(N_D_t[u, i] for u in 1:t) + sum(x1[r] * δ(1, v, r) for v in 2:t for r in 𝐷[1, i]) + sum(x[u, r] * δ(u, v, r) for u in 2:(t-1) for v in (u+1):t for r in 𝐷[u, i]))
                    end    
                end 
            elseif  isempty(𝐹[1]) == true && all(isequal(Set()), 𝐹[2:end]) == false
                #println(isempty(𝐹[1]), " - ", all(isequal(Set()), 𝐹[2:end]))
                @stochastic_model model begin
                    @stage 1 begin
                        @decision(model, x1[𝑅[1]], Int)
                        @decision(model, z1[𝐿[1]], Int)
                        @decision(model, v1[𝐽_initial[1]], Int)
                        @decision(model, w1[𝐽[1]] >= 0)
                        @constraint(model, nonneg1[r in 𝑅[1]], x1[r] >= 0)
                        @constraint(model, nonneg3[l in 𝐿[1]], z1[l] >= 0)
                        @constraint(model, nonneg4[j in 𝐽_initial[1]], v1[j] >= 0)
                        #@constraint(model, nonneg4[j in 𝐽[1]], w1[j] >= 0)
                        @constraint(model, directing1[j in 𝐽_initial[1]], sum(z1[l] for l in 𝐿_customer[1, j]) + v1[j] == D_t[1, j])
                        @constraint(model, satisfy_demand1[j in 𝐽[1]], sum(x1[r] for r in 𝑅_customer[1, j]) + w1[j] == round(N_F_t[1, j]) + sum(z1[l] for l in 𝐿_overline[1, j]))
                        @constraint(model, supply_conservation1[i in 1:I], sum(x1[r] for r in 𝑂[1, i]) <= N_D_t[1, i])
                        @objective(model, Max, sum((α * DR[1, r] + (1-α) * -DT[r])* x1[r] for r in 𝑅[1]) + sum((α * LC[l] + (1-α) * -LT[l]) * z1[l] for l in 𝐿[1]) + sum((α * 0.0 + (1-α) * -RT_1[j]) * v1[j] for j in 𝐽_initial[1]) + sum((α * RC[1, j] + (1-α) * -RT_2[j]) * w1[j] for j in 𝐽[1]))
                    end
                    @stage 2 begin
                        @uncertain D_stoch 
                        @recourse(model, x[t in 2:Q_t, 𝑅[t]] >= 0)
                        @recourse(model, y[t in 2:Q_t, 𝐹[t]] >= 0)
                        @recourse(model, z[t in 2:Q_t, 𝐿[t]] >= 0)
                        @recourse(model, v[t in 2:Q_t, 𝐽_initial[t]] >= 0)
                        @recourse(model, w[t in 2:Q_t, 𝐽[t]] >= 0)
                        @objective(model, Max, sum((α * DR[t, r] + (1-α) * -DT[r]) * x[t, r] for t in 2:Q_t for r in 𝑅[t]) +  sum((α * FC[f] + (1 - α) * -FT[f]) * y[t, f] for t in 2:Q_t for f in 𝐹[t]) + sum((α * LC[l] + (1-α) * -LT[l]) * z[t, l] for t in 2:Q_t for l in 𝐿[t]) + sum((α * 0.0 + (1-α) * -RT_1[j]) * v[t, j] for t in 2:Q_t for j in 𝐽_initial[t]) + sum((α * RC[t, j] + (1-α) * -RT_2[j]) * w[t, j] for t in 2:Q_t for j in 𝐽[t]))     
                        @constraint(model, directing[t in 2:Q_t, j in 𝐽_initial[t]], sum(y[t, f] for f in 𝐹_customer[t, j]) + sum(z[t, l] for l in 𝐿_customer[t, j]) + v[t, j] == D_stoch[t, j])
                        @constraint(model, satisfy_demand2[j in 𝐽[2]], sum(x[2, r] for r in 𝑅_customer[2, j]) + w[2, j] == 
                        round(N_F_t[2, j]) + sum(z[2, l] for l in 𝐿_overline[2, j]))  
                        @constraint(model, satisfy_demand[t in 3:Q_t, j in 𝐽[t]], sum(x[t, r] for r in 𝑅_customer[t, j]) + w[t, j] == 
                        round(N_F_t[t, j]) + sum(y[u, f] * ϵ(u, t, f) for u in 2:(t-1) for f in 𝐹_overline[u, j]) + sum(z[t, l] for l in 𝐿_overline[t, j]))
                        @constraint(model, supply_conservation2[i in 1:I], sum(x1[r] for r in 𝑂[1, i]) + sum(x[2, r] for r in 𝑂[2, i]) <= sum(N_D_t[u, i] for u in 1:2) + sum(x1[r] * δ(1, 2, r) for r in 𝐷[1, i]))
                        @constraint(model, supply_conservation[t in 3:Q_t, i in 1:I], sum(x1[r] for r in 𝑂[1, i]) + sum(x[u, r] for u in 2:t for r in 𝑂[u, i]) <= sum(N_D_t[u, i] for u in 1:t) + sum(x1[r] * δ(1, v, r) for v in 2:t for r in 𝐷[1, i]) + sum(x[u, r] * δ(u, v, r) for u in 2:(t-1) for v in (u+1):t for r in 𝐷[u, i]))
                    end    
                end   
            end
        end

        ξ1 = nothing
        ξ2 = nothing
        ξ3 = nothing
        ξ4 = nothing
        ξ5 = nothing
        ξ6 = nothing
        ξ7 = nothing
        ξ8 = nothing
        ξ9 = nothing
        ξ10 = nothing
        ξ11 = nothing
        ξ12 = nothing
        ξ13 = nothing
        ξ14 = nothing
        ξ15 = nothing
        ξ16 = nothing
        ξ17 = nothing
        ξ18 = nothing
        ξ19 = nothing
        ξ20 = nothing

        for s in 1:S
            if s == 1 
                ξ1 = @scenario D_stoch = D_train[:, :, 1] probability = 1/S
            elseif s == 2 
                ξ2 = @scenario D_stoch = D_train[:, :, 2] probability = 1/S
            elseif s == 3 
                ξ3 = @scenario D_stoch = D_train[:, :, 3] probability = 1/S
            elseif s == 4 
                ξ4 = @scenario D_stoch = D_train[:, :, 4] probability = 1/S
            elseif s == 5 
                ξ5 = @scenario D_stoch = D_train[:, :, 5] probability = 1/S
            elseif s == 6 
                ξ6 = @scenario D_stoch = D_train[:, :, 6] probability = 1/S
            elseif s == 7 
                ξ7 = @scenario D_stoch = D_train[:, :, 7] probability = 1/S
            elseif s == 8 
                ξ8 = @scenario D_stoch = D_train[:, :, 8] probability = 1/S
            elseif s == 9 
                ξ9 = @scenario D_stoch = D_train[:, :, 9] probability = 1/S
            elseif s == 10 
                ξ10 = @scenario D_stoch = D_train[:, :, 10] probability = 1/S
            elseif s == 11 
                ξ11 = @scenario D_stoch = D_train[:, :, 11] probability = 1/S
            elseif s == 12 
                ξ12 = @scenario D_stoch = D_train[:, :, 12] probability = 1/S
            elseif s == 13 
                ξ13 = @scenario D_stoch = D_train[:, :, 13] probability = 1/S
            elseif s == 14 
                ξ14 = @scenario D_stoch = D_train[:, :, 14] probability = 1/S
            elseif s == 15 
                ξ15 = @scenario D_stoch = D_train[:, :, 15] probability = 1/S
            elseif s == 16 
                ξ16 = @scenario D_stoch = D_train[:, :, 16] probability = 1/S
            elseif s == 17 
                ξ17 = @scenario D_stoch = D_train[:, :, 17] probability = 1/S
            elseif s == 18 
                ξ18 = @scenario D_stoch = D_train[:, :, 18] probability = 1/S
            elseif s == 19 
                ξ19 = @scenario D_stoch = D_train[:, :, 19] probability = 1/S
            elseif s == 20 
                ξ20 = @scenario D_stoch = D_train[:, :, 20] probability = 1/S
            end
        end 

        if S == 1
            ξ = [ξ1]
        elseif S == 2
            ξ = [ξ1, ξ2]
        elseif S == 3
            ξ = [ξ1, ξ2, ξ3]
        elseif S == 4
            ξ = [ξ1, ξ2, ξ3, ξ4]
        elseif S == 5
            ξ = [ξ1, ξ2, ξ3, ξ4, ξ5]
        elseif S == 6
            ξ = [ξ1, ξ2, ξ3, ξ4, ξ5, ξ6]
        elseif S == 7
            ξ = [ξ1, ξ2, ξ3, ξ4, ξ5, ξ6, ξ7]
        elseif S == 8
            ξ = [ξ1, ξ2, ξ3, ξ4, ξ5, ξ6, ξ7, ξ8]
        elseif S == 9
            ξ = [ξ1, ξ2, ξ3, ξ4, ξ5, ξ6, ξ7, ξ8, ξ9]
        elseif S == 10
            ξ = [ξ1, ξ2, ξ3, ξ4, ξ5, ξ6, ξ7, ξ8, ξ9, ξ10]
        elseif S == 11
            ξ = [ξ1, ξ2, ξ3, ξ4, ξ5, ξ6, ξ7, ξ8, ξ9, ξ10, ξ11]
        elseif S == 12
            ξ = [ξ1, ξ2, ξ3, ξ4, ξ5, ξ6, ξ7, ξ8, ξ9, ξ10, ξ11, ξ12]
        elseif S == 13
            ξ = [ξ1, ξ2, ξ3, ξ4, ξ5, ξ6, ξ7, ξ8, ξ9, ξ10, ξ11, ξ12, ξ13]
        elseif S == 14
            ξ = [ξ1, ξ2, ξ3, ξ4, ξ5, ξ6, ξ7, ξ8, ξ9, ξ10, ξ11, ξ12, ξ13, ξ14]
        elseif S == 15
            ξ = [ξ1, ξ2, ξ3, ξ4, ξ5, ξ6, ξ7, ξ8, ξ9, ξ10, ξ11, ξ12, ξ13, ξ14, ξ15]
        elseif S == 16
            ξ = [ξ1, ξ2, ξ3, ξ4, ξ5, ξ6, ξ7, ξ8, ξ9, ξ10, ξ11, ξ12, ξ13, ξ14, ξ15, ξ16]
        elseif S == 17
            ξ = [ξ1, ξ2, ξ3, ξ4, ξ5, ξ6, ξ7, ξ8, ξ9, ξ10, ξ11, ξ12, ξ13, ξ14, ξ15, ξ16, ξ17]
        elseif S == 18
            ξ = [ξ1, ξ2, ξ3, ξ4, ξ5, ξ6, ξ7, ξ8, ξ9, ξ10, ξ11, ξ12, ξ13, ξ14, ξ15, ξ16, ξ17, ξ18]
        elseif S == 19
            ξ = [ξ1, ξ2, ξ3, ξ4, ξ5, ξ6, ξ7, ξ8, ξ9, ξ10, ξ11, ξ12, ξ13, ξ14, ξ15, ξ16, ξ17, ξ18, ξ19]
        elseif S == 20
            ξ = [ξ1, ξ2, ξ3, ξ4, ξ5, ξ6, ξ7, ξ8, ξ9, ξ10, ξ11, ξ12, ξ13, ξ14, ξ15, ξ16, ξ17, ξ18, ξ19, ξ20]
        end 
        if l_shaped
            problem = instantiate(model, ξ, optimizer = LShaped.Optimizer)

            #set_silent(problem)
            set_optimizer_attribute(problem, MasterOptimizer(), Gurobi.Optimizer)
            set_optimizer_attribute(problem, SubProblemOptimizer(), Gurobi.Optimizer)
            set_optimizer_attributes(problem, τ = 0.005)
            problem_stage_1 = stage_one_model(problem, optimizer = Gurobi.Optimizer)
            #set_silent(problem_stage_1)
            #set_optimizer_attribute(problem, FeasibilityStrategy(), FeasibilityCuts())
            optimize!(problem, crash = Crash.FeasiblePoint()) 
        else
            problem = instantiate(model, ξ, optimizer = Gurobi.Optimizer)
            #set_silent(problem)
            problem_stage_1 = stage_one_model(problem, optimizer = Gurobi.Optimizer)
            #set_silent(problem_stage_1)
            optimize!(problem, crash = Crash.FeasiblePoint())
            #set_optimizer_attributes(problem, "PoolSearchMode", 2)
            #set_optimizer_attributes(problem, "PoolSolutions", 10)
        end
         
        x1 = value.(problem[1, :x1])
        #for r in 𝑅[1]
        #    println("r: ", r, " - ",x1[r])
        #end

        y1 = nothing
        if Q_t > 2
            if isempty(𝐹[1]) != true 
                y1 = value.(problem[1, :y1])
            end
        end
        z1 = value.(problem[1, :z1])
        #for l in 𝐿[1]
        #    println("l: ", l," - ", z1[l])
        #end
        v1 = value.(problem[1, :v1])
        w1 = value.(problem[1, :w1])

        x = value.(problem[2, :x], 1)
        y = nothing
        if Q_t > 2
            if all(isequal(Set()), 𝐹[2:end]) == false
                y = value.(problem[2, :y], 1)
            end     
        end
        z = value.(problem[2, :z], 1)
        v = value.(problem[2, :v], 1)
        w = value.(problem[2, :w], 1)

        dispatching_revenues_first_period = sum((α * DR[1, r] + (1-α) * -DT[r]) * x1[r] for r in 𝑅[1]; init=0.0)
        dispatching_revenues1_first_period = sum(DR[1, r]  * x1[r] for r in 𝑅[1]; init=0.0)
        dispatching_revenues2_first_period = sum(-DT[r] * x1[r] for r in 𝑅[1]; init=0.0)

        first_mile_costs_first_period = 0.0
        first_mile_costs1_first_period = 0.0
        first_mile_costs2_first_period = 0.0

        if Q_t > 2
            if isempty(𝐹[1]) == false 
                first_mile_costs_first_period =  sum((α * FC[f] + (1-α) * -FT[f]) * y1[f] for f in 𝐹[1]; init=0.0)
                first_mile_costs1_first_period =  sum(FC[f] * y1[f] for f in 𝐹[1]; init=0.0)
                first_mile_costs2_first_period =  sum(-FT[f] * y1[f] for f in 𝐹[1]; init=0.0)
            end
        else 
            nothing
        end
        

        last_mile_costs_first_period = sum((α * LC[l] + (1-α) * -LT[l]) * z1[l] for l in 𝐿[1]; init=0.0)
        last_mile_costs1_first_period = sum(LC[l] * z1[l] for l in 𝐿[1]; init=0.0)
        last_mile_costs2_first_period = sum(-LT[l] * z1[l] for l in 𝐿[1]; init=0.0)

        

        rejection_costs_first_period = sum((α * 0.0 + (1-α) * -RT_1[j]) * v1[j] for j in 𝐽_initial[1]; init=0.0)
        rejection_costs1_first_period = 0.0
        rejection_costs2_first_period = sum(-RT_1[j] * v1[j] for j in 𝐽_initial[1]; init=0.0)

        cancelation_costs_first_period = sum((α * RC[1, j] + (1-α) * -RT_2[j]) * w1[j] for j in 𝐽[1]; init=0.0)
        cancelation_costs1_first_period = sum(RC[1, j] * w1[j] for j in 𝐽[1]; init=0.0)
        cancelation_costs2_first_period = sum(-RT_2[j] * w1[j] for j in 𝐽[1]; init=0.0)

        obj_value_first_period = dispatching_revenues_first_period + first_mile_costs_first_period + last_mile_costs_first_period + rejection_costs_first_period + cancelation_costs_first_period
        obj_value1_first_period = dispatching_revenues1_first_period + first_mile_costs1_first_period + last_mile_costs1_first_period + rejection_costs1_first_period + cancelation_costs1_first_period
        obj_value2_first_period = dispatching_revenues2_first_period + first_mile_costs2_first_period + last_mile_costs2_first_period + rejection_costs2_first_period + cancelation_costs2_first_period

        #println("DR revenues 1 : ", dispatching_revenues1_first_period)
        #println("DR costs 2 : ", dispatching_revenues2_first_period)
        #println("FM costs 1 : ", first_mile_costs1_first_period)
        #println("FM costs 2 : ", first_mile_costs2_first_period)
        #println("LM costs 1 : ", last_mile_costs1_first_period)
        #println("LM costs 2 : ", last_mile_costs2_first_period)
        #println("Rej costs 1 : ", rejection_costs1_first_period)
        #println("Rej costs 2 : ", rejection_costs2_first_period)
        #println("Canc costs 1 : ", cancelation_costs1_first_period)
        #println("Canc costs 2 : ", cancelation_costs2_first_period)
        #println("Obj value 1 : ", obj_value1_first_period)
        #println("Obj value 2 : ", obj_value2_first_period)

        obj_value = objective_value(problem)
        
        return (
        x1, 
        y1, 
        z1,
        v1,
        w1,
        obj_value_first_period,
        obj_value1_first_period,
        obj_value2_first_period,
        obj_value)
    end 
end


function formulate_and_solve_dep_problem(
    𝐽_initial::Vector{Set}, 
    𝐽::Vector{Set}, 
    𝑅::Vector{Set}, 
    𝑅_customer::Dict{Any, Any}, 
    𝑂::Matrix{Set}, 
    𝐷::Matrix{Set}, 
    𝐹::Vector{Set}, 
    𝐹_customer::Dict{Any, Any}, 
    𝐹_overline::Dict{Any, Any}, 
    𝐿::Vector{Set}, 
    𝐿_customer::Dict{Any, Any}, 
    𝐿_overline::Dict{Any, Any},
    D_t::Matrix{Float64},
    D_train::Array{Float64, 3}, 
    N_D_t::Matrix{Float64},
    N_F_t::Matrix{Float64}, 
    DR::Dict{Any, Any}, 
    FC::Dict{Any, Any},
    LC::Dict{Any, Any},
    RC::Dict{Any, Any},
    DT::Dict{Any, Any},
    FT::Dict{Any, Any},
    LT::Dict{Any, Any},
    RT_1::Dict{Any, Any},
    RT_2::Dict{Any, Any},
    S::Int64,
    Q_t::Int64,
    I::Int64,
    l_shaped::Bool,
    offline::Bool,
    α::Float64)
    #println("We solve here now!!!!!!!!!!!")
    function δ(t, t′, r)
        if t + floor(DT[r]) + 1 == t′
            return 1.0
        else
            return 0.0
        end
    end
    
    function ϵ(t, t′, f)
        if t + floor(FT[f]) + 1 == t′
            return 1.0
        else
            return 0.0
        end
    end

    if Q_t == 1 
        problem = Model(Gurobi.Optimizer)
        set_silent(problem)
        set_optimizer_attribute(problem, "TimeLimit", 600)

        @variable(problem, x1[𝑅[1]], Int) 
        @variable(problem, z1[𝐿[1]], Int)
        @variable(problem, v1[𝐽_initial[1]], Int)
        @variable(problem, w1[𝐽[1]] >= 0)
        @constraint(problem, nonneg1[r in 𝑅[1]], x1[r] >= 0)
        @constraint(problem, nonneg3[l in 𝐿[1]], z1[l] >= 0)
        @constraint(problem, nonneg4[j in 𝐽_initial[1]], v1[j] >= 0)
        @constraint(problem, directing[j in 𝐽_initial[1]], sum(z1[l] for l in 𝐿_customer[1, j]) + v1[j] == D_t[1, j])
        @constraint(problem, satisfy_demand1[j in 𝐽[1]], sum(x1[r] for r in 𝑅_customer[1, j]) + w1[j] == round(N_F_t[1, j]) + sum(z1[l] for l in 𝐿_overline[1, j]))
        @constraint(problem, supply_conservation1[i in 1:I], sum(x1[r] for r in 𝑂[1, i]) <= N_D_t[1, i])
        @objective(problem, Max, sum((α * DR[1, r] + (1-α) * -DT[r]) * x1[r] for r in 𝑅[1]) + sum((α * LC[l] + (1-α) * -LT[l]) * z1[l] for l in 𝐿[1]) + sum((α * 0.0 + (1-α) * -RT_1[j]) * v1[j] for j in 𝐽_initial[1]) + sum((α * RC[1, j] + (1-α) * -RT_2[j]) * w1[j] for j in 𝐽[1]))

        optimize!(problem)
        x1 = value.(problem[:x1])
        y1 = zeros(I^2)
        z1 = value.(problem[:z1])
        v1 = value.(problem[:v1])
        w1 = value.(problem[:w1])

        obj_value_first_period = sum((α * DR[1, r] + (1-α) * -DT[r]) * x1[r] for r in 𝑅[1]; init=0.0) + sum((α * LC[l] + (1-α) * -LT[l]) * z1[l] for l in 𝐿[1]; init=0.0) + sum((α * 0.0 + (1-α) * -RT_1[j]) * v1[j] for j in 𝐽_initial[1]; init=0.0) + sum((α * RC[1, j] + (1-α) * -RT_2[j]) * w1[j] for j in 𝐽[1]; init=0.0)
        obj_value1_first_period = sum(DR[1, r] * x1[r] for r in 𝑅[1]; init=0.0) + sum(LC[l] * z1[l] for l in 𝐿[1]; init=0.0) + sum(0.0 * v1[j] for j in 𝐽_initial[1]; init=0.0) + sum(RC[1, j] * w1[j] for j in 𝐽[1]; init=0.0)
        obj_value2_first_period = sum(-DT[r] * x1[r] for r in 𝑅[1]; init=0.0) + sum(-LT[l] * z1[l] for l in 𝐿[1]; init=0.0) + sum(-RT_1[j] * v1[j] for j in 𝐽_initial[1]; init=0.0) + sum(-RT_2[j] * w1[j] for j in 𝐽[1]; init=0.0)

        obj_value = objective_value(problem)

        return (
        x1, 
        y1, 
        z1,
        v1,
        w1,
        obj_value_first_period,
        obj_value1_first_period,
        obj_value2_first_period,
        obj_value)

    else
        if Q_t == 2
            problem = Model(Gurobi.Optimizer)
            set_silent(problem)
            set_optimizer_attribute(problem, "TimeLimit", 600)
            @variable(problem, x1[𝑅[1]], Int) 
            @variable(problem, z1[𝐿[1]], Int)
            @variable(problem, v1[𝐽_initial[1]], Int)
            @variable(problem, w1[𝐽[1]] >= 0)
            @variable(problem, x[t in 2:Q_t, 𝑅[t], s in 1:S] >= 0)
            @variable(problem, z[t in 2:Q_t, 𝐿[t], s in 1:S] >= 0)
            @variable(problem, v[t in 2:Q_t, 𝐽_initial[t], s in 1:S] >= 0)
            @variable(problem, w[t in 2:Q_t, 𝐽[t], s in 1:S] >= 0)
            @objective(problem, Max, sum((α * DR[1, r] + (1-α) * -DT[r]) * x1[r] for r in 𝑅[1]) + sum((α * LC[l] + (1-α) * -LT[l]) * z1[l] for l in 𝐿[1]) + sum((α * 0.0 + (1-α) * -RT_1[j]) * v1[j] for j in 𝐽_initial[1]) + sum((α * RC[1, j] + (1-α) * -RT_2[j]) * w1[j] for j in 𝐽[1])
            + 1/S*(sum((α * DR[t, r] + (1-α) * -DT[r]) * x[t, r, s] for t in 2:Q_t for r in 𝑅[t] for s in 1:S) + sum((α * LC[l] + (1-α) * -LT[l]) * z[t, l, s] for t in 2:Q_t for l in 𝐿[t] for s in 1:S) + sum((α * 0.0 + (1-α) * -RT_1[j]) * v[t, j, s] for t in 2:Q_t for j in 𝐽_initial[t] for s in 1:S) + sum((α * RC[t, j] + (1-α) * -RT_2[j]) * w[t, j, s] for t in 2:Q_t for j in 𝐽[t] for s in 1:S)))   
            @constraint(problem, nonneg1[r in 𝑅[1]], x1[r] >= 0)
            @constraint(problem, nonneg3[l in 𝐿[1]], z1[l] >= 0)
            @constraint(problem, nonneg4[j in 𝐽_initial[1]], v1[j] >= 0)
            @constraint(problem, directing1[j in 𝐽_initial[1]], sum(z1[l] for l in 𝐿_customer[1, j]) + v1[j] == D_t[1, j])
            @constraint(problem, satisfy_demand1[j in 𝐽[1]], sum(x1[r] for r in 𝑅_customer[1, j]) + w1[j] == round(N_F_t[1, j]) + sum(z1[l] for l in 𝐿_overline[1, j]))
            @constraint(problem, supply_conservation1[i in 1:I], sum(x1[r] for r in 𝑂[1, i]) <= N_D_t[1, i])
            @constraint(problem, directing[t in 2:Q_t, j in 𝐽_initial[t], s in 1:S], sum(z[t, l, s] for l in 𝐿_customer[t, j]) + v[t, j, s] == D_train[t, j, s])
            @constraint(problem, satisfy_demand2[j in 𝐽[2], s in 1:S], sum(x[2, r, s] for r in 𝑅_customer[2, j]) + w[2, j, s] == round(N_F_t[2, j]) + sum(z[2, l, s] for l in 𝐿_overline[2, j]))  
            @constraint(problem, supply_conservation2[i in 1:I, s in 1:S], sum(x1[r] for r in 𝑂[1, i]) + sum(x[2, r, s] for r in 𝑂[2, i]) <= sum(N_D_t[u, i] for u in 1:2) + sum(x1[r] * δ(1, 2, r) for r in 𝐷[1, i]))
        else    
            if isempty(𝐹[1]) == false && all(isequal(Set()), 𝐹[2:end]) == false
                #println(isempty(𝐹[1]), " - ", all(isequal(Set()), 𝐹[2:end]))
                problem = Model(Gurobi.Optimizer)
                set_silent(problem)
                set_optimizer_attribute(problem, "TimeLimit", 600)
                @variable(problem, x1[𝑅[1]], Int)
                @variable(problem, y1[𝐹[1]], Int)
                @variable(problem, z1[𝐿[1]], Int)
                @variable(problem, v1[𝐽_initial[1]], Int)
                @variable(problem, w1[𝐽[1]] >= 0)
                @variable(problem, x[t in 2:Q_t, 𝑅[t], s in 1:S] >= 0)
                @variable(problem, y[t in 2:Q_t, 𝐹[t], s in 1:S] >= 0)
                @variable(problem, z[t in 2:Q_t, 𝐿[t], s in 1:S] >= 0)
                @variable(problem, v[t in 2:Q_t, 𝐽_initial[t], s in 1:S] >= 0)
                @variable(problem, w[t in 2:Q_t, 𝐽[t], s in 1:S] >= 0)
                @objective(problem, Max, sum((α * DR[1, r] + (1-α) * -DT[r])* x1[r] for r in 𝑅[1]) + sum((α * FC[f] + (1 - α) * -FT[f]) * y1[f] for f in 𝐹[1]) + sum((α * LC[l] + (1-α) * -LT[l]) * z1[l] for l in 𝐿[1]) + sum((α * 0.0 + (1-α) * -RT_1[j]) * v1[j] for j in 𝐽_initial[1]) + sum((α * RC[1, j] + (1-α) * -RT_2[j]) * w1[j] for j in 𝐽[1])
                + 1/S*(sum((α * DR[t, r] + (1-α) * -DT[r]) * x[t, r, s] for t in 2:Q_t for r in 𝑅[t] for s in 1:S) +  sum((α * FC[f] + (1 - α) * -FT[f]) * y[t, f, s] for t in 2:Q_t for f in 𝐹[t] for s in 1:S) + sum((α * LC[l] + (1-α) * -LT[l]) * z[t, l, s] for t in 2:Q_t for l in 𝐿[t] for s in 1:S) + sum((α * 0.0 + (1-α) * -RT_1[j]) * v[t, j, s] for t in 2:Q_t for j in 𝐽_initial[t] for s in 1:S) + sum((α * RC[t, j] + (1-α) * -RT_2[j]) * w[t, j, s] for t in 2:Q_t for j in 𝐽[t] for s in 1:S)))     
                @constraint(problem, nonneg1[r in 𝑅[1]], x1[r] >= 0)
                @constraint(problem, nonneg2[f in 𝐹[1]], y1[f] >= 0)
                @constraint(problem, nonneg3[l in 𝐿[1]], z1[l] >= 0)
                @constraint(problem, nonneg4[j in 𝐽_initial[1]], v1[j] >= 0)
                @constraint(problem, directing1[j in 𝐽_initial[1]], sum(y1[f] for f in 𝐹_customer[1, j]) + sum(z1[l] for l in 𝐿_customer[1, j]) + v1[j] == D_t[1, j])                        
                @constraint(problem, satisfy_demand1[j in 𝐽[1]], sum(x1[r] for r in 𝑅_customer[1, j]) + w1[j] == round(N_F_t[1, j]) + sum(z1[l] for l in 𝐿_overline[1, j]))
                @constraint(problem, supply_conservation1[i in 1:I], sum(x1[r] for r in 𝑂[1, i]) <= N_D_t[1, i])
                @constraint(problem, directing[t in 2:Q_t, j in 𝐽_initial[t], s in 1:S], sum(y[t, f, s] for f in 𝐹_customer[t, j]) + sum(z[t, l, s] for l in 𝐿_customer[t, j]) + v[t, j, s] == D_train[t, j, s])
                @constraint(problem, satisfy_demand2[j in 𝐽[2], s in 1:S], sum(x[2, r, s] for r in 𝑅_customer[2, j]) + w[2, j, s] == 
                round(N_F_t[2, j]) + sum(y1[f] * ϵ(1, 2, f) for f in 𝐹_overline[1, j]) + sum(z[2, l, s] for l in 𝐿_overline[2, j]))  
                @constraint(problem, satisfy_demand[t in 3:Q_t, j in 𝐽[t], s in 1:S], sum(x[t, r, s] for r in 𝑅_customer[t, j]) + w[t, j, s] == 
                round(N_F_t[t, j]) + sum(y1[f] * ϵ(1, t, f) for f in 𝐹_overline[1, j]) + sum(y[u, f, s] * ϵ(u, t, f) for u in 2:(t-1) for f in 𝐹_overline[u, j]) + sum(z[t, l, s] for l in 𝐿_overline[t, j]))
                @constraint(problem, supply_conservation2[i in 1:I, s in 1:S], sum(x1[r] for r in 𝑂[1, i]) + sum(x[2, r, s] for r in 𝑂[2, i]) <= sum(N_D_t[u, i] for u in 1:2) + sum(x1[r] * δ(1, 2, r) for r in 𝐷[1, i]))
                @constraint(problem, supply_conservation[t in 3:Q_t, i in 1:I, s in 1:S], sum(x1[r] for r in 𝑂[1, i]) + sum(x[u, r, s] for u in 2:t for r in 𝑂[u, i]) <= sum(N_D_t[u, i] for u in 1:t) + sum(x1[r] * δ(1, v, r) for v in 2:t for r in 𝐷[1, i]) + sum(x[u, r, s] * δ(u, v, r) for u in 2:(t-1) for v in (u+1):t for r in 𝐷[u, i]))    
                  
            elseif  isempty(𝐹[1]) == true && all(isequal(Set()), 𝐹[2:end]) == true
                #println(isempty(𝐹[1]), " - ", all(isequal(Set()), 𝐹[2:end]))
                problem = Model(Gurobi.Optimizer)
                set_silent(problem)
                set_optimizer_attribute(problem, "TimeLimit", 600)
                @variable(problem, x1[𝑅[1]], Int)
                @variable(problem, z1[𝐿[1]], Int)
                @variable(problem, v1[𝐽_initial[1]], Int)
                @variable(problem, w1[𝐽[1]] >= 0)
                @variable(problem, x[t in 2:Q_t, 𝑅[t], s in 1:S] >= 0)
                @variable(problem, z[t in 2:Q_t, 𝐿[t], s in 1:S] >= 0)
                @variable(problem, v[t in 2:Q_t, 𝐽_initial[t], s in 1:S] >= 0)
                @variable(problem, w[t in 2:Q_t, 𝐽[t], s in 1:S] >= 0)
                @objective(problem, Max, sum((α * DR[1, r] + (1-α) * -DT[r]) * x1[r] for r in 𝑅[1]) + sum((α * LC[l] + (1-α) * -LT[l]) * z1[l] for l in 𝐿[1]) + sum((α * 0.0 + (1-α) * -RT_1[j]) * v1[j] for j in 𝐽_initial[1]) + sum((α * RC[1, j] + (1-α) * -RT_2[j]) * w1[j] for j in 𝐽[1])
                + 1/S*(sum((α * DR[t, r] + (1-α) * -DT[r]) * x[t, r, s] for t in 2:Q_t for r in 𝑅[t] for s in 1:S) + sum((α * LC[l] + (1-α) * -LT[l]) * z[t, l, s] for t in 2:Q_t for l in 𝐿[t] for s in 1:S) + sum((α * 0.0 + (1-α) * -RT_1[j]) * v[t, j, s] for t in 2:Q_t for j in 𝐽_initial[t] for s in 1:S) + sum((α * RC[t, j] + (1-α) * -RT_2[j]) * w[t, j, s] for t in 2:Q_t for j in 𝐽[t] for s in 1:S)))     
                @constraint(problem, nonneg1[r in 𝑅[1]], x1[r] >= 0)
                @constraint(problem, nonneg3[l in 𝐿[1]], z1[l] >= 0)
                @constraint(problem, nonneg4[j in 𝐽_initial[1]], v1[j] >= 0)
                @constraint(problem, directing1[j in 𝐽_initial[1]], sum(z1[l] for l in 𝐿_customer[1, j]) + v1[j] == D_t[1, j])
                @constraint(problem, satisfy_demand1[j in 𝐽[1]], sum(x1[r] for r in 𝑅_customer[1, j]) + w1[j] == round(N_F_t[1, j]) + sum(z1[l] for l in 𝐿_overline[1, j]))
                @constraint(problem, supply_conservation1[i in 1:I], sum(x1[r] for r in 𝑂[1, i]) <= N_D_t[1, i])
                @constraint(problem, directing[t in 2:Q_t, j in 𝐽_initial[t], s in 1:S], sum(z[t, l, s] for l in 𝐿_customer[t, j]) + v[t, j, s] == D_train[t, j, s])
                @constraint(problem, satisfy_demand2[j in 𝐽[2], s in 1:S], sum(x[2, r, s] for r in 𝑅_customer[2, j]) + w[2, j, s] == 
                round(N_F_t[2, j]) + sum(z[2, l, s] for l in 𝐿_overline[2, j]))  
                @constraint(problem, satisfy_demand[t in 3:Q_t, j in 𝐽[t], s in 1:S], sum(x[t, r, s] for r in 𝑅_customer[t, j]) + w[t, j, s] == 
                round(N_F_t[t, j]) + sum(z[t, l, s] for l in 𝐿_overline[t, j]))
                @constraint(problem, supply_conservation2[i in 1:I, s in 1:S], sum(x1[r] for r in 𝑂[1, i]) + sum(x[2, r, s] for r in 𝑂[2, i]) <= sum(N_D_t[u, i] for u in 1:2) + sum(x1[r] * δ(1, 2, r) for r in 𝐷[1, i]))
                @constraint(problem, supply_conservation[t in 3:Q_t, i in 1:I, s in 1:S], sum(x1[r] for r in 𝑂[1, i]) + sum(x[u, r, s] for u in 2:t for r in 𝑂[u, i]) <= sum(N_D_t[u, i] for u in 1:t) + sum(x1[r] * δ(1, v, r) for v in 2:t for r in 𝐷[1, i]) + sum(x[u, r, s] * δ(u, v, r) for u in 2:(t-1) for v in (u+1):t for r in 𝐷[u, i]))
            
            elseif  isempty(𝐹[1]) == false && all(isequal(Set()), 𝐹[2:end]) == true
                #println(isempty(𝐹[1]), " - ", all(isequal(Set()), 𝐹[2:end]))
                problem = Model(Gurobi.Optimizer)
                set_silent(problem)
                set_optimizer_attribute(problem, "TimeLimit", 600)
                @variable(problem, x1[𝑅[1]], Int)
                @variable(problem, y1[𝐹[1]], Int)
                @variable(problem, z1[𝐿[1]], Int)
                @variable(problem, v1[𝐽_initial[1]], Int)
                @variable(problem, w1[𝐽[1]] >= 0)
                @variable(problem, x[t in 2:Q_t, 𝑅[t], s in 1:S] >= 0)
                @variable(problem, z[t in 2:Q_t, 𝐿[t], s in 1:S] >= 0)
                @variable(problem, v[t in 2:Q_t, 𝐽_initial[t], s in 1:S] >= 0)
                @variable(problem, w[t in 2:Q_t, 𝐽[t], s in 1:S] >= 0)
                @objective(problem, Max, sum((α * DR[1, r] + (1-α) * -DT[r]) * x1[r] for r in 𝑅[1]) + sum((α * FC[f] + (1 - α) * -FT[f]) * y1[f] for f in 𝐹[1]) + sum((α * LC[l] + (1-α) * -LT[l]) * z1[l] for l in 𝐿[1]) + sum((α * 0.0 + (1-α) * -RT_1[j]) * v1[j] for j in 𝐽_initial[1]) + sum((α * RC[1, j] + (1-α) * -RT_2[j]) * w1[j] for j in 𝐽[1])
                + 1/S*(sum((α * DR[t, r] + (1-α) * -DT[r]) * x[t, r, s] for t in 2:Q_t for r in 𝑅[t] for s in 1:S) + sum((α * LC[l] + (1-α) * -LT[l]) * z[t, l, s] for t in 2:Q_t for l in 𝐿[t] for s in 1:S) + sum((α * 0.0 + (1-α) * -RT_1[j]) * v[t, j, s] for t in 2:Q_t for j in 𝐽_initial[t] for s in 1:S) + sum((α * RC[t, j] + (1-α) * -RT_2[j]) * w[t, j, s] for t in 2:Q_t for j in 𝐽[t] for s in 1:S)))     
                @constraint(problem, nonneg1[r in 𝑅[1]], x1[r] >= 0)
                @constraint(problem, nonneg2[f in 𝐹[1]], y1[f] >= 0)
                @constraint(problem, nonneg3[l in 𝐿[1]], z1[l] >= 0)
                @constraint(problem, nonneg4[j in 𝐽_initial[1]], v1[j] >= 0)
                @constraint(problem, directing1[j in 𝐽_initial[1]], sum(y1[f] for f in 𝐹_customer[1, j]) + sum(z1[l] for l in 𝐿_customer[1, j]) + v1[j] == D_t[1, j])
                @constraint(problem, satisfy_demand1[j in 𝐽[1]], sum(x1[r] for r in 𝑅_customer[1, j]) + w1[j] == round(N_F_t[1, j]) + sum(z1[l] for l in 𝐿_overline[1, j]))
                @constraint(problem, supply_conservation1[i in 1:I], sum(x1[r] for r in 𝑂[1, i]) <= N_D_t[1, i])
                @constraint(problem, directing[t in 2:Q_t, j in 𝐽_initial[t], s in 1:S], sum(z[t, l, s] for l in 𝐿_customer[t, j]) + v[t, j, s] == D_train[t, j, s])
                @constraint(problem, satisfy_demand2[j in 𝐽[2], s in 1:S], sum(x[2, r, s] for r in 𝑅_customer[2, j]) + w[2, j, s] == 
                round(N_F_t[2, j]) + sum(y1[f] * ϵ(1, 2, f) for f in 𝐹_overline[1, j]) + sum(z[2, l, s] for l in 𝐿_overline[2, j]))  
                @constraint(problem, satisfy_demand[t in 3:Q_t, j in 𝐽[t], s in 1:S], sum(x[t, r, s] for r in 𝑅_customer[t, j]) + w[t, j, s] == 
                round(N_F_t[t, j]) + sum(y1[f] * ϵ(1, t, f) for f in 𝐹_overline[1, j]) + sum(z[t, l, s] for l in 𝐿_overline[t, j]))
                @constraint(problem, supply_conservation2[i in 1:I, s in 1:S], sum(x1[r] for r in 𝑂[1, i]) + sum(x[2, r, s] for r in 𝑂[2, i]) <= sum(N_D_t[u, i] for u in 1:2) + sum(x1[r] * δ(1, 2, r) for r in 𝐷[1, i]))
                @constraint(problem, supply_conservation[t in 3:Q_t, i in 1:I, s in 1:S], sum(x1[r] for r in 𝑂[1, i]) + sum(x[u, r, s] for u in 2:t for r in 𝑂[u, i]) <= sum(N_D_t[u, i] for u in 1:t) + sum(x1[r] * δ(1, v, r) for v in 2:t for r in 𝐷[1, i]) + sum(x[u, r, s] * δ(u, v, r) for u in 2:(t-1) for v in (u+1):t for r in 𝐷[u, i]))
            
            elseif  isempty(𝐹[1]) == true && all(isequal(Set()), 𝐹[2:end]) == false
                #println(isempty(𝐹[1]), " - ", all(isequal(Set()), 𝐹[2:end]))
                problem = Model(Gurobi.Optimizer)
                set_silent(problem)
                set_optimizer_attribute(problem, "TimeLimit", 600)
                @variable(problem, x1[𝑅[1]], Int)
                @variable(problem, z1[𝐿[1]], Int)
                @variable(problem, v1[𝐽_initial[1]], Int)
                @variable(problem, w1[𝐽[1]] >= 0)
                @variable(problem, x[t in 2:Q_t, 𝑅[t], s in 1:S] >= 0)
                @variable(problem, y[t in 2:Q_t, 𝐹[t], s in 1:S] >= 0)
                @variable(problem, z[t in 2:Q_t, 𝐿[t], s in 1:S] >= 0)
                @variable(problem, v[t in 2:Q_t, 𝐽_initial[t], s in 1:S] >= 0)
                @variable(problem, w[t in 2:Q_t, 𝐽[t], s in 1:S] >= 0)
                @objective(problem, Max, sum((α * DR[1, r] + (1-α) * -DT[r])* x1[r] for r in 𝑅[1]) + sum((α * LC[l] + (1-α) * -LT[l]) * z1[l] for l in 𝐿[1]) + sum((α * 0.0 + (1-α) * -RT_1[j]) * v1[j] for j in 𝐽_initial[1]) + sum((α * RC[1, j] + (1-α) * -RT_2[j]) * w1[j] for j in 𝐽[1])
                + 1/S*(sum((α * DR[t, r] + (1-α) * -DT[r]) * x[t, r, s] for t in 2:Q_t for r in 𝑅[t] for s in 1:S) +  sum((α * FC[f] + (1 - α) * -FT[f]) * y[t, f, s] for t in 2:Q_t for f in 𝐹[t] for s in 1:S) + sum((α * LC[l] + (1-α) * -LT[l]) * z[t, l, s] for t in 2:Q_t for l in 𝐿[t] for s in 1:S) + sum((α * 0.0 + (1-α) * -RT_1[j]) * v[t, j, s] for t in 2:Q_t for j in 𝐽_initial[t] for s in 1:S) + sum((α * RC[t, j] + (1-α) * -RT_2[j]) * w[t, j, s] for t in 2:Q_t for j in 𝐽[t] for s in 1:S)))     
                @constraint(problem, nonneg1[r in 𝑅[1]], x1[r] >= 0)
                @constraint(problem, nonneg3[l in 𝐿[1]], z1[l] >= 0)
                @constraint(problem, nonneg4[j in 𝐽_initial[1]], v1[j] >= 0)
                @constraint(problem, directing1[j in 𝐽_initial[1]], sum(z1[l] for l in 𝐿_customer[1, j]) + v1[j] == D_t[1, j])                        
                @constraint(problem, satisfy_demand1[j in 𝐽[1]], sum(x1[r] for r in 𝑅_customer[1, j]) + w1[j] == round(N_F_t[1, j]) + sum(z1[l] for l in 𝐿_overline[1, j]))
                @constraint(problem, supply_conservation1[i in 1:I], sum(x1[r] for r in 𝑂[1, i]) <= N_D_t[1, i])
                @constraint(problem, directing[t in 2:Q_t, j in 𝐽_initial[t], s in 1:S], sum(y[t, f, s] for f in 𝐹_customer[t, j]) + sum(z[t, l, s] for l in 𝐿_customer[t, j]) + v[t, j, s] == D_train[t, j, s])
                @constraint(problem, satisfy_demand2[j in 𝐽[2], s in 1:S], sum(x[2, r, s] for r in 𝑅_customer[2, j]) + w[2, j, s] == 
                round(N_F_t[2, j]) + sum(z[2, l, s] for l in 𝐿_overline[2, j]))  
                @constraint(problem, satisfy_demand[t in 3:Q_t, j in 𝐽[t], s in 1:S], sum(x[t, r, s] for r in 𝑅_customer[t, j]) + w[t, j, s] == 
                round(N_F_t[t, j]) + sum(y[u, f, s] * ϵ(u, t, f) for u in 2:(t-1) for f in 𝐹_overline[u, j]) + sum(z[t, l, s] for l in 𝐿_overline[t, j]))
                @constraint(problem, supply_conservation2[i in 1:I, s in 1:S], sum(x1[r] for r in 𝑂[1, i]) + sum(x[2, r, s] for r in 𝑂[2, i]) <= sum(N_D_t[u, i] for u in 1:2) + sum(x1[r] * δ(1, 2, r) for r in 𝐷[1, i]))
                @constraint(problem, supply_conservation[t in 3:Q_t, i in 1:I, s in 1:S], sum(x1[r] for r in 𝑂[1, i]) + sum(x[u, r, s] for u in 2:t for r in 𝑂[u, i]) <= sum(N_D_t[u, i] for u in 1:t) + sum(x1[r] * δ(1, v, r) for v in 2:t for r in 𝐷[1, i]) + sum(x[u, r, s] * δ(u, v, r) for u in 2:(t-1) for v in (u+1):t for r in 𝐷[u, i]))             
            end
        end

        optimize!(problem)

        x1 = value.(problem[:x1])
        y1 = nothing
        if Q_t > 2
            if isempty(𝐹[1]) != true 
                y1 = value.(problem[:y1])
            end
        end
        z1 = value.(problem[:z1])
        v1 = value.(problem[:v1])
        w1 = value.(problem[:w1])

        dispatching_revenues_first_period = sum((α * DR[1, r] + (1-α) * -DT[r]) * x1[r] for r in 𝑅[1]; init=0.0)
        dispatching_revenues1_first_period = sum(DR[1, r]  * x1[r] for r in 𝑅[1]; init=0.0)
        dispatching_revenues2_first_period = sum(-DT[r] * x1[r] for r in 𝑅[1]; init=0.0)

        first_mile_costs_first_period = 0.0
        first_mile_costs1_first_period = 0.0
        first_mile_costs2_first_period = 0.0

        if Q_t > 2
            if isempty(𝐹[1]) == false 
                first_mile_costs_first_period =  sum((α * FC[f] + (1-α) * -FT[f]) * y1[f] for f in 𝐹[1]; init=0.0)
                first_mile_costs1_first_period =  sum(FC[f] * y1[f] for f in 𝐹[1]; init=0.0)
                first_mile_costs2_first_period =  sum(-FT[f] * y1[f] for f in 𝐹[1]; init=0.0)
            end
        else 
            nothing
        end
        
        last_mile_costs_first_period = sum((α * LC[l] + (1-α) * -LT[l]) * z1[l] for l in 𝐿[1]; init=0.0)
        last_mile_costs1_first_period = sum(LC[l] * z1[l] for l in 𝐿[1]; init=0.0)
        last_mile_costs2_first_period = sum(-LT[l] * z1[l] for l in 𝐿[1]; init=0.0)

        rejection_costs_first_period = sum((α * 0.0 + (1-α) * -RT_1[j]) * v1[j] for j in 𝐽_initial[1]; init=0.0)
        rejection_costs1_first_period = 0.0
        rejection_costs2_first_period = sum(-RT_1[j] * v1[j] for j in 𝐽_initial[1]; init=0.0)

        cancelation_costs_first_period = sum((α * RC[1, j] + (1-α) * -RT_2[j]) * w1[j] for j in 𝐽[1]; init=0.0)
        cancelation_costs1_first_period = sum(RC[1, j] * w1[j] for j in 𝐽[1]; init=0.0)
        cancelation_costs2_first_period = sum(-RT_2[j] * w1[j] for j in 𝐽[1]; init=0.0)

        obj_value_first_period = dispatching_revenues_first_period + first_mile_costs_first_period + last_mile_costs_first_period + rejection_costs_first_period + cancelation_costs_first_period
        obj_value1_first_period = dispatching_revenues1_first_period + first_mile_costs1_first_period + last_mile_costs1_first_period + rejection_costs1_first_period + cancelation_costs1_first_period
        obj_value2_first_period = dispatching_revenues2_first_period + first_mile_costs2_first_period + last_mile_costs2_first_period + rejection_costs2_first_period + cancelation_costs2_first_period

        obj_value = objective_value(problem)
        
        return (
        x1, 
        y1, 
        z1,
        v1,
        w1,
        obj_value_first_period,
        obj_value1_first_period,
        obj_value2_first_period,
        obj_value)
    end 
end

function formulate_and_solve_offline_problem(
    𝐽_initial::Vector{Set}, 
    𝐽::Vector{Set}, 
    𝑅::Vector{Set}, 
    𝑅_customer::Dict{Any, Any}, 
    𝑂::Matrix{Set}, 
    𝐷::Matrix{Set}, 
    𝐹::Vector{Set}, 
    𝐹_customer::Dict{Any, Any}, 
    𝐹_overline::Dict{Any, Any}, 
    𝐿::Vector{Set}, 
    𝐿_customer::Dict{Any, Any}, 
    𝐿_overline::Dict{Any, Any},
    D_t::Matrix{Float64},
    N_D_t::Matrix{Float64},
    DR::Dict{Any, Any}, 
    FC::Dict{Any, Any}, 
    LC::Dict{Any, Any},
    DT::Dict{Any, Any}, 
    FT::Dict{Any, Any}, 
    LT::Dict{Any, Any},
    RT_1::Dict{Any, Any},
    T_offline::Int64,
    I::Int64,
    α::Float64)

    function δ(t, t′, r)
        if t + floor(DT[r]) + 1 == t′
            return true
        else
            return false
        end
    end
    
    function ϵ(t, t′, f)
        if t + floor(FT[f]) + 1 == t′
            return true
        else
            return false
        end
    end            
    
    problem = Model(Gurobi.Optimizer)
    set_silent(problem)
    set_optimizer_attribute(problem, "TimeLimit", 900)

    @variable(problem, x[t in 1:T_offline, 𝑅[t]] >= 0)
    @variable(problem, y[t in 1:T_offline, 𝐹[t]] >= 0)
    @variable(problem, z[t in 1:T_offline, 𝐿[t]] >= 0)
    @variable(problem, v[t in 1:T_offline, 𝐽_initial[t]] >= 0)

    @objective(problem, Max, sum((α * DR[t, r] + (1-α) * -DT[r]) * x[t, r] for t in 1:T_offline for r in 𝑅[t]) +  sum((α * FC[f] + (1 - α) * -FT[f]) * y[t, f] for t in 1:T_offline for f in 𝐹[t]) + sum((α * LC[l] + (1-α) * -LT[l]) * z[t, l] for t in 1:T_offline for l in 𝐿[t]) + sum((α * 0.0 + (1-α) * -RT_1[j]) * v[t, j] for t in 1:T_offline for j in 𝐽_initial[t]))     
    @constraint(problem, directing[t in 1:T_offline, j in 𝐽_initial[t]], sum(y[t, f] for f in 𝐹_customer[t, j]) + sum(z[t, l] for l in 𝐿_customer[t, j]) + v[t, j] == D_t[t, j])
    @constraint(problem, satisfy_demand1[j in 𝐽[1]], sum(x[1, r] for r in 𝑅_customer[1, j]) == sum(z[1, l] for l in 𝐿_overline[1, j]))
    @constraint(problem, satisfy_demand[t in 1:T_offline, j in 𝐽[t]], sum(x[t, r] for r in 𝑅_customer[t, j]) == sum(y[u, f] * ϵ(u, t, f) for u in 1:(t-1) for f in 𝐹_overline[u, j]) + sum(z[t, l] for l in 𝐿_overline[t, j]))
    @constraint(problem, supply_conservation1[i in 1:I], sum(x[1, r] for r in 𝑂[1, i]) <= N_D_t[1, i])
    @constraint(problem, supply_conservation[t in 2:T_offline, i in 1:I], sum(x[u, r] for u in 1:t for r in 𝑂[u, i]) <= N_D_t[1, i] + sum(x[u, r] * δ(u, v, r) for u in 1:(t-1) for v in (u+1):t for r in 𝐷[u, i]))
                    
    optimize!(problem)

    x = value.(problem[:x])
    y = value.(problem[:y])
    z = value.(problem[:z])
    v = value.(problem[:v])
    obj_value = objective_value(problem)
    obj_value1 = sum(DR[t, r] * x[t, r] for t in 1:T_offline for r in 𝑅[t]; init = 0.0) +  sum(FC[f] * y[t, f] for t in 1:T_offline for f in 𝐹[t]; init = 0.0) + sum(LC[l] * z[t, l] for t in 1:T_offline for l in 𝐿[t]; init = 0.0)
    obj_value2 = sum(-DT[r] * x[t, r] for t in 1:T_offline for r in 𝑅[t]; init = 0.0) +  sum(-FT[f] * y[t, f] for t in 1:T_offline for f in 𝐹[t]; init = 0.0) + sum(-LT[l] * z[t, l] for t in 1:T_offline for l in 𝐿[t]; init = 0.0) + sum(-RT_1[j] * v[t, j] for t in 1:T_offline for j in 𝐽_initial[t]; init = 0.0)
    return (
    x, 
    y, 
    z,
    v,
    obj_value,
    obj_value1,
    obj_value2)
end

function update_state(
    N_D_t::Matrix{Float64},
    N_F_t::Matrix{Float64},
    x1::Any,
    y1::Any,
    𝐽::Vector{Set}, 
    𝑂::Matrix{Set},
    𝐷::Matrix{Set}, 
    𝐹_overline::Dict{Any, Any},
    FT::Dict{Any, Any}, 
    DT::Dict{Any, Any},
    I::Int64, 
    Service::Int64)

    function δ(t, t′, r)
        if t + floor(DT[r]) + 1 == t′
            return true
        else
            return false
        end
    end
    
    function ϵ(t, t′, f)
        if t + floor(FT[f]) + 1 == t′
            return true
        else
            return false
        end
    end

    for i in 1:I
        #println("Number of drivers: ", N_D_t[1, i], " - Number of dispatched: ", sum(x1[r] for r in 𝑂[1, i]; init=0.0))
        N_D_t[1, i] -= sum(x1[r] for r in 𝑂[1, i]; init=0.0) 
    end

    for t in 2:(size(N_D_t)[1])
        for i in 1:I
            N_D_t[t, i] += sum(x1[r] * δ(1, t, r) for r in 𝐷[1, i]; init=0.0)
        end
    end  
    
    for i in 1:I
        N_D_t[2, i] += N_D_t[1, i]
    end

    N_D_t = N_D_t[2:end, :]
    if (Service == 1 || Service == 2)
        for t in 2:(size(𝐽)[1])
            for j in 𝐽[t]
                N_F_t[t, j] += sum(y1[f] * ϵ(1, t, f) for f in 𝐹_overline[1, j]; init = 0.0)
            end
        end
    end
    N_F_t = N_F_t[2:end,:]
    return (N_D_t, N_F_t)
end

function RunOnline(
    T_horizon::Int64,
    Max_DispatchingRoutesPerCust::Int64,
    S::Int64,
    Q::Int64, 
    N_D::Matrix{Float64}, 
    N_F::Matrix{Float64}, 
    D_test::Matrix{Float64},
    D_train::Array{Float64, 3}, 
    l_shaped::Bool,
    Service::Int64,
    α::Float64)

    objective_online = 0.0
    objective_online1 = 0.0
    objective_online2 = 0.0

    N_D_t = N_D
    N_F_t = N_F
 
    dispatched_drivers = 0
    FM_customers = 0
    LM_customers = 0
    D2D_customers = 0
    rejected_customers = 0
    canceled_customers = 0 

    x = Dict()
    y = Dict()
    z = Dict()
    v = Dict()
    w = Dict()
    N = zeros(size(N_D)[2], T_horizon)
    F = zeros(size(N_F)[2], T_horizon)

    for t in 1:T_horizon
       Q_t = Q
       if T_horizon - t + 1 < Q
          Q_t =  T_horizon - t + 1
       end
       #println("t is ", t)
       #println("S is ", S)
       #println("Q is ", Q_t)
       #println("|R| is ", Max_DispatchingRoutesPerCust)
       #println("L-Shaped?", l_shaped)
       #initial_type_1 = repeat(initial_type_now[t, :], 1, S)
       #initial_type_1 = reshape(initial_type_1, (1, J, S))
       #local initial_type = vcat(initial_type_1, initial_type_past[t+1 : T, :, :])

       N[:, t] = N_D_t[1, :]
       F[:, t] = N_F_t[1, :]

       offline = false 
 
       D_t = D_test[t : end, :]
       D_t_future = D_train[t : end, :, 1 : S]

       #println("Number of drivers: ", sum(N_D_t))

       #for t in 1:size(N_D_t)[1]
       #     for i in 1:size(N_D_t)[2]
       #         if N_D_t[t, i] != 0
       #             println("N_D ", t, " - ", i, " - ", N_D_t[t, i])
       #         end
       #     end
       #end

       𝐽_initial = build_initial_customer_type_sets(D_t, D_t_future, Q_t, S)
       if (Service == 1) || (Service == 2)
            (𝐹, 𝐹_customer) = build_initial_fm_route_sets(Min_ServiceT, Max_AdditionalT, Min_Reduction, 
            𝐽_initial, ServiceT, origin, transfer_FM, FT_bis, DR_bis, Q_t)
       else 
            𝐹 = Vector{Set}(undef, Q_t) 
            for t in 1:Q_t
                𝐹[t] = Set() 
            end
            𝐹_customer = Dict() 
       end
       if (Service == 1) || (Service == 3)
            (𝐿, 𝐿_customer) = build_initial_lm_route_sets(Min_ServiceT, Max_AdditionalT, Min_Reduction, 
            𝐽_initial, ServiceT, destination, transfer_LM, LT_bis, DR_bis, Q_t)
       else
            (𝐿, 𝐿_customer) = build_initial_d2d_route_sets(Min_ServiceT, Max_AdditionalT, Min_Reduction, 
            𝐽_initial, ServiceT, destination, transfer_LM, LT_bis, DR_bis, Q_t)
       end
       𝐽 = build_final_customer_type_sets(𝐹, transfer_FM, FT_bis, 𝐿, transfer_LM, N_F_t, Q_t)
       if (Service == 1) || (Service == 2)
            𝐹_overline = build_final_fm_route_sets(𝐽, 𝐹, transfer_FM, Q_t)
       else 
            𝐹_overline = Dict()
       end 

       𝐿_overline = build_final_lm_route_sets(𝐽, 𝐿, transfer_LM, Q_t)
       (𝑅, 𝑅_customer, 𝑂, 𝐷) = build_dispatching_route_sets(Max_DispatchingRoutesPerCust, 𝐽, PickupT, destination, N_D_t, Q_t, I)
       (DR, LC, FC, RC, DT, LT, FT, RT_1, RT_2) = build_dictionaries(𝐽, 𝐽_initial,
       𝑅, 𝐿, 𝐹, DR_bis, LC_bis, FC_bis, DT_bis, LT_bis, FT_bis, RT_bis, Q_t)
       (x1, y1, z1, v1, w1, obj_value_1st_period, obj_value1_1st_period, obj_value2_1st_period, _) = formulate_and_solve_optimization_problem(𝐽_initial, 𝐽, 𝑅, 𝑅_customer, 𝑂, 𝐷, 𝐹, 𝐹_customer, 𝐹_overline, 𝐿, 𝐿_customer, 𝐿_overline,
       D_t, D_t_future, N_D_t, N_F_t, DR, FC, LC, RC, DT, FT, LT, RT_1, RT_2, S, Q_t, I, l_shaped, offline, α)
       (N_D_t, N_F_t) = update_state(N_D_t, N_F_t, x1, y1, 𝐽, 𝑂, 𝐷, 𝐹_overline, FT, DT, I, Service) 

       for r in 𝑅[1]
        push!(x, (t, r) => value(x1[r]))
       end

       for f in 𝐹[1]
        push!(y, (t, f) => value(y1[f]))
       end

       for l in 𝐿[1]
        push!(z, (t, l) => value(z1[l]))
       end

       for j in 𝐽_initial[1]
        push!(v, (t, j) => value(v1[j]))
       end

       for j in 𝐽[1]
        push!(w, (t, j) => value(w1[j]))
       end

       objective_online += obj_value_1st_period
       objective_online1 += obj_value1_1st_period
       objective_online2 += obj_value2_1st_period

       dispatched_drivers += sum(x1; init=0.0)
       
       if y1 != nothing
        FM_customers += sum(y1; init=0.0)
       else 
        FM_customers += 0.0
       end
       #println("y1: ", sum(y1; init = 0.0))
       #println("z1: ", sum(z1[l] for l in 𝐿[1] if destination[l[1]]!=l[2]; init = 0.0))
       LM_customers += sum(z1[l] for l in 𝐿[1] if destination[l[1]]!=l[2]; init = 0.0)
       D2D_customers += sum(z1[l] for l in 𝐿[1] if destination[l[1]]==l[2]; init = 0.0)
       rejected_customers += sum(v1[j] for j in 𝐽_initial[1]; init=0.0)
       canceled_customers += sum(w1[j] for j in 𝐽[1]; init=0.0)

       #println("FM customers: ", FM_customers)
       #println("LM customers: ", LM_customers)
       #println("D2D customers: ", D2D_customers)
       #println("rejected customers: ", rejected_customers)
       #println("canceled customers: ", canceled_customers)
    end
    return x, y, z, v, w, N, F, dispatched_drivers, FM_customers, LM_customers, D2D_customers, rejected_customers, canceled_customers, objective_online, objective_online1, objective_online2
end
 
#Offline problem
 
function RunOffline(
    T_offline::Int64,
    N_D::Matrix{Float64}, 
    N_F::Matrix{Float64}, 
    D_test::Matrix{Float64},
    α::Float64)

    l_shaped = false
    offline = true 
    D_t = D_test[:, :]
    D_t_future = D_test[:, :]
    D_t_future = reshape(D_t_future, (T_offline, J, 1))
    S = 1

    Max_DispatchingRoutesPerCust = 16

    N_D_t = N_D
    N_F_t = N_F
    𝐽_initial = build_initial_customer_type_sets(D_t, D_t_future, T_offline, S)
    (𝐹, 𝐹_customer) = build_initial_fm_route_sets(Min_ServiceT, Max_AdditionalT, Min_Reduction, 
    𝐽_initial, ServiceT, origin, transfer_FM, FT_bis, DR_bis, T_offline)
    (𝐿, 𝐿_customer) = build_initial_lm_route_sets(Min_ServiceT, Max_AdditionalT, Min_Reduction, 
    𝐽_initial, ServiceT, destination, transfer_LM, LT_bis, DR_bis, T_offline)
    𝐽 = build_final_customer_type_sets(𝐹, transfer_FM, FT_bis, 𝐿, transfer_LM, N_F_t, T_offline)
    𝐹_overline = build_final_fm_route_sets(𝐽, 𝐹, transfer_FM, T_offline)
    𝐿_overline = build_final_lm_route_sets(𝐽, 𝐿, transfer_LM, T_offline)
    (𝑅, 𝑅_customer, 𝑂, 𝐷) = build_dispatching_route_sets(Max_DispatchingRoutesPerCust, 𝐽, PickupT, destination, N_D_t, T_offline, I)
    (DR, LC, FC, RC, DT, LT, FT, RT_1, RT_2) = build_dictionaries(𝐽, 𝐽_initial, 𝑅, 𝐿, 𝐹, DR_bis, LC_bis, FC_bis, DT_bis, LT_bis, FT_bis, RT_bis, T_offline)
    (_, _, _, _, objective_offline, objective_offline1, objective_offline2) = formulate_and_solve_offline_problem(𝐽_initial, 𝐽, 𝑅, 𝑅_customer, 𝑂, 𝐷, 𝐹, 𝐹_customer, 𝐹_overline, 𝐿, 𝐿_customer, 𝐿_overline,
    D_t, N_D_t, DR, FC, LC, DT, FT, LT, RT_1, T_offline, I, α)
    return objective_offline, objective_offline1, objective_offline2 
end
 