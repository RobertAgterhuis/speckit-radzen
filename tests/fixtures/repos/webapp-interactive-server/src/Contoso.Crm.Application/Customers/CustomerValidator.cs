using FluentValidation;
namespace Contoso.Crm.Application.Customers;
public sealed class CustomerValidator : AbstractValidator<CustomerDto>
{
    public CustomerValidator() => RuleFor(x => x.Name).NotEmpty();
}
