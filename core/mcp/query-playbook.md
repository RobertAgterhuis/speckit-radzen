# Radzen MCP Query Playbook

Recipes for the Radzen Blazor MCP `search` tool. Replace `<…>`. One concern per query; include the installed Radzen version when behaviour may differ between versions (see `.speckit/radzen/profile.md`).

## Setup and wiring

| Need | Query |
|---|---|
| Service registration | `Radzen Blazor AddRadzenComponents service registration Program.cs, which services does it register (DialogService, NotificationService, TooltipService, ContextMenuService)` |
| Component host | `Radzen Blazor RadzenComponents component in MainLayout with @rendermode <InteractiveServer/InteractiveAuto>, what it hosts` |
| Theme | `Radzen Blazor RadzenTheme component theme names and how to switch theme at runtime, Radzen.Blazor <version>` |
| Render mode | `Radzen Blazor components in .NET <8/9/10> Blazor Web App with static SSR pages, which components need interactive render mode` |

## Data grid

| Need | Query |
|---|---|
| Server paging/sorting/filtering | `RadzenDataGrid LoadData server-side paging sorting filtering with Count and IsLoading for TItem <Type> with properties <…>` |
| Filter translation | `RadzenDataGrid LoadDataArgs Filters collection (FilterDescriptor) to build a server-side query without using the Filter string` |
| Column templates / formatting | `RadzenDataGridColumn Template and FormatString for <DateTime/decimal> column` |
| Row selection | `RadzenDataGrid SelectionMode Multiple with @bind-Value selected items` |
| Inline editing | `RadzenDataGrid inline edit EditRow UpdateRow CancelEditRow with EditTemplate and validation` |
| Responsive columns | `RadzenDataGrid responsive behaviour, hiding columns on small screens, column Visible and Width` |
| Virtualization | `RadzenDataGrid AllowVirtualization with LoadData` |
| Reload after change | `RadzenDataGrid Reload method after create/update/delete` |

## Forms and validation

| Need | Query |
|---|---|
| Form | `RadzenTemplateForm TItem <Type> Submit and InvalidSubmit, with RadzenFormField / RadzenTextBox` |
| Validators | `Radzen validators RadzenRequiredValidator RadzenLengthValidator RadzenRegexValidator RadzenCompareValidator Component name binding` |
| DataAnnotations | `RadzenTemplateForm with DataAnnotationsValidator and RadzenDataAnnotationValidator` |
| Busy submit | `RadzenButton IsBusy BusyText ButtonType Submit disable during submit` |
| Numeric/date inputs | `RadzenNumeric TValue decimal? Min Max Format` / `RadzenDatePicker TValue DateTime? DateFormat culture` |

## Dropdowns and lookups

| Need | Query |
|---|---|
| Server data | `RadzenDropDown LoadData with AllowFiltering and Count for large lookup lists` |
| Cascading | `Radzen cascading RadzenDropDown Change event reload dependent dropdown` |
| Autocomplete | `RadzenAutoComplete LoadData MinLength FilterDelay` |

## Dialogs and notifications

| Need | Query |
|---|---|
| Open component dialog | `Radzen DialogService OpenAsync<TComponent> with parameters and DialogOptions Width, result on close` |
| Confirm | `Radzen DialogService Confirm options OkButtonText CancelButtonText return value when closed` |
| Close with result | `Radzen DialogService Close(result) from inside dialog component` |
| Side dialog | `Radzen DialogService OpenSideAsync options` |
| Notification | `Radzen NotificationService Notify NotificationMessage Severity Summary Detail Duration` |

## Layout, navigation, other components

| Need | Query |
|---|---|
| Layout | `RadzenLayout RadzenHeader RadzenSidebar RadzenBody responsive sidebar toggle` |
| Stack/Row/Column | `RadzenStack Orientation Gap JustifyContent AlignItems Wrap` / `RadzenRow RadzenColumn Size SizeMD SizeSM` |
| Tabs / steps | `RadzenTabs RenderMode Client/Server SelectedIndex` / `RadzenSteps with validation between steps` |
| Tree | `RadzenTree Data Expand LoadData for hierarchical lazy loading` |
| Upload | `RadzenUpload Url vs Auto=false with custom upload, MaxFileSize, Accept, progress` |
| Scheduler | `RadzenScheduler TItem views LoadData AppointmentSelect SlotSelect` |
| Charts | `RadzenChart RadzenColumnSeries CategoryProperty ValueProperty with RadzenValueAxis formatting` |
| Accessibility | `Radzen Blazor accessibility keyboard navigation aria-label support for <component>` |

## Query anti-patterns

- "Make a grid page" — too broad; split per concern.
- Asking for a whole page and pasting it as-is — the output ignores repository architecture (P-02).
- Omitting the component name — the search returns unrelated results.
- Re-asking what the evidence log already answers — wastes quota.
