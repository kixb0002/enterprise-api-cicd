namespace Enterprise.Api.UnitTests;

public class ProductTests
{
    [Fact]
    public void Product_Price_Should_Be_Positive()
    {
        var price = 1200;

        Assert.True(price > 0);
    }

    [Theory]
    [InlineData(1)]
    [InlineData(10)]
    [InlineData(100)]
    public void Product_Id_Should_Be_Positive(int id)
    {
        Assert.True(id > 0);
    }
}
