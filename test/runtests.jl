using Test

@testset "OmniTools.jl" begin
    using OmniTools

    @testset "ForNumber basics" begin
        @test clamp_zero_one(2.0) == 1.0
        @test clamp_zero_one(-0.5) == 0.0
        @test clamp_zero_one(0.25) == 0.25

        @test safe_divide(1.0, 2.0) == 0.5
        @test safe_divide(1.0, 0.0) == 1.0

        @test is_invalid_number(NaN)
        @test is_invalid_number(Inf)
        @test is_invalid_number(missing)
        @test is_invalid_number(nothing)
        @test !is_invalid_number(1.0)

        @test replace_invalid_number(NaN, 0.0) == 0.0
        @test replace_invalid_number(2.0, 0.0) == 2.0

        out = zeros(Int, 3)
        @test cumulative_sum!(out, [1, 2, 3]) == [1, 3, 6]

        @test at_least_zero(-1.0) == 0.0
        @test at_least_one(0.5) == 1.0
        @test at_most_zero(1.0) == 0.0
        @test at_most_one(2.0) == 1.0
    end

    @testset "ForString basics" begin
        @test to_uppercase_first("hello_world", "Time") == :TimeHelloWorld
        @test to_uppercase_first("hello_world") == :HelloWorld
        @test to_uppercase_first("", "X") == :X
    end

    @testset "ForCollections basics" begin
        nt = dict_to_namedtuple(Dict(:a => 1, :b => 2))
        @test nt.a == 1
        @test nt.b == 2
    end

    @testset "ForArray basics" begin
        @test positive_mask([1.0, 0.0, -1.0]) == BitVector([1, 0, 0])
        @test positive_mask([1.0, NaN, -1.0]) == BitVector([1, 0, 0])
    end
end


