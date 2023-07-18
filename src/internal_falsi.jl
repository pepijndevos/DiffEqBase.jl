"""
  prevfloat_tdir(x, x0, x1)

Move `x` one floating point towards x0.
"""
function prevfloat_tdir(x, x0, x1)
    x1 > x0 ? prevfloat(x) : nextfloat(x)
end

function nextfloat_tdir(x, x0, x1)
    x1 > x0 ? nextfloat(x) : prevfloat(x)
end

function max_tdir(a, b, x0, x1)
    x1 > x0 ? max(a, b) : min(a, b)
end

"""
`InternalFalsi`: A non-allocating regula falsi method, internal to DiffEqBase for
simpler dependencies.
"""
struct InternalFalsi end

function SciMLBase.solve(prob::IntervalNonlinearProblem, alg::InternalFalsi, args...;
    maxiters = 1000,
    kwargs...)
    f = Base.Fix2(prob.f, prob.p)
    left, right = prob.tspan
    fl, fr = f(left), f(right)

    if iszero(fl)
        return SciMLBase.build_solution(prob, alg, left, fl;
            retcode = ReturnCode.ExactSolutionLeft, left = left,
            right = right)
    end

    i = 1
    if !iszero(fr)
        using_falsi_steps = true
        while i < maxiters
            # First, perform a regula falsi iteration
            if using_falsi_steps
                if nextfloat_tdir(left, prob.tspan...) == right
                    return SciMLBase.build_solution(prob, alg, left, fl;
                        retcode = ReturnCode.FloatingPointLimit,
                        left = left, right = right)
                end
                mid = (fr * left - fl * right) / (fr - fl)
                for i in 1:10
                    mid = max_tdir(left, prevfloat_tdir(mid, prob.tspan...), prob.tspan...)
                end
                if mid == right || mid == left
                    using_falsi_steps = false
                    continue
                end
                fm = f(mid)
                if iszero(fm)
                    right = mid
                    using_falsi_steps = false
                    continue
                end
                if sign(fl) == sign(fm)
                    fl = fm
                    left = mid
                else
                    fr = fm
                    right = mid
                end
                i += 1
            end

            # Then, perform a bisection iteration
            mid = (left + right) / 2
            (mid == left || mid == right) &&
                return SciMLBase.build_solution(prob, alg, left, fl;
                    retcode = ReturnCode.FloatingPointLimit,
                    left = left, right = right)
            fm = f(mid)
            if iszero(fm)
                right = mid
                fr = fm
            elseif sign(fm) == sign(fl)
                left = mid
                fl = fm
            else
                right = mid
                fr = fm
            end
            i += 1
        end
    end

    return SciMLBase.build_solution(prob, alg, left, fl; retcode = ReturnCode.MaxIters,
        left = left, right = right)
end
