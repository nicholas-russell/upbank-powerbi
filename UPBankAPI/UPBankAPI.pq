section UPBankAPI;

// Load common library functions
// Note that when the extension is built, files are all placed in the same directory. 
// Therefore when referencing them here, they should be without their sub directory

Extension.LoadFunction = (name as text) =>
    let
        binary = Extension.Contents(name),
        asText = Text.FromBinary(binary)
    in
        Expression.Evaluate(asText, #shared);

// All in util/
shared Table.ToNavigationTable = Extension.LoadFunction("Table.ToNavigationTable.pqm");
shared Table.GetAllPagesByNextLink = Extension.LoadFunction("Table.GetAllPagesByNextLink.pqm");
shared Table.GenerateByPage = Extension.LoadFunction("Table.GenerateByPage.pqm");

// Base Up API Url
BaseUrl = "https://api.up.com.au/api/v1/";

//Authentication 
UPBankAPI = [
    Authentication = [
        Key = [
            KeyLabel = Extension.LoadString("AuthKeyLabel"),
            Label = Extension.LoadString("AuthLabel")
        ]
    ],
    Label = Extension.LoadString("DataSourceLabel")
];

UPBankAPI.Publish = [
    Beta = true,
    Category = "Other",
    ButtonText = { Extension.LoadString("ButtonTitle"), Extension.LoadString("ButtonHelp") },
    LearnMoreUrl = "https://github.com/nicholas-russell/upbank-powerbi",
    SourceImage = UPBankAPI.Icons,
    SourceTypeImage = UPBankAPI.Icons
];

UPBankAPI.Icons = [
    Icon16 = { Extension.Contents("UPBankAPI16.png"), Extension.Contents("UPBankAPI20.png"), Extension.Contents("UPBankAPI24.png"), Extension.Contents("UPBankAPI32.png") },
    Icon32 = { Extension.Contents("UPBankAPI32.png"), Extension.Contents("UPBankAPI40.png"), Extension.Contents("UPBankAPI48.png"), Extension.Contents("UPBankAPI64.png") }
];


// Headers required for API
DefaultRequestHeaders = [
    #"Authorization" = "Bearer " & Extension.CurrentCredential()[Key]
];

// Function to extract the "next" link for paginated queries
GetNextLink = (response) as nullable text => 
     Record.FieldOrDefault(response[links], "next");


//-- API tables below --//

UPBankAPI.Ping = (optional message as text) =>
    let
        Source = Json.Document(Web.Contents("https://api.up.com.au/api/v1/" & "util/ping", [Headers=DefaultRequestHeaders])),
        rtn = Source[meta]
    in
        rtn;


UPBankAPI.Categories = () =>
    let
        Source = Json.Document(Web.Contents(BaseUrl & "categories", [Headers=DefaultRequestHeaders])),
        data = Source[data],
        #"Converted to Table" = Table.FromList(data, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
        #"Expanded Column1" = Table.ExpandRecordColumn(#"Converted to Table", "Column1", {"type", "id", "attributes", "relationships"}, {"type", "id", "attributes", "relationships"}),
        #"Expanded attributes" = Table.ExpandRecordColumn(#"Expanded Column1", "attributes", {"name"}, {"attributes.name"}),
        #"Expanded relationships" = Table.ExpandRecordColumn(#"Expanded attributes", "relationships", {"parent"}, {"relationships.parent"}),
        #"Expanded relationships.parent" = Table.ExpandRecordColumn(#"Expanded relationships", "relationships.parent", {"data"}, {"relationships.parent.data"}),
        #"Expanded relationships.parent.data" = Table.ExpandRecordColumn(#"Expanded relationships.parent", "relationships.parent.data", {"id"}, {"relationships.parent.data.id"}),
        #"Changed Type" = Table.TransformColumnTypes(#"Expanded relationships.parent.data",{{"type", type text}, {"id", type text}, {"attributes.name", type text}, {"relationships.parent.data.id", type text}})
    in
        #"Changed Type";


GetTagPage = (url as text) =>
    let
        Source = Json.Document(Web.Contents(url, [Headers=DefaultRequestHeaders])),
        data = Source[data],
        nextLink = GetNextLink(Source),
        #"Converted to Table" = Table.FromList(data, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
        #"Expanded Column1" = Table.ExpandRecordColumn(#"Converted to Table", "Column1", {"type", "id"}, {"type", "id"}),
        #"Changed Type" = Table.TransformColumnTypes(#"Expanded Column1",{{"type", type text}, {"id", type text}})
    in
        #"Changed Type" meta [NextLink = nextLink];

UPBankAPI.Tags = () => Table.GetAllPagesByNextLink(BaseUrl & "tags", GetTagPage);

GetTransactionPage = (url as text) as table =>
    let
        Source = Json.Document(Web.Contents(url, [Headers=DefaultRequestHeaders])),
        data = Source[data],
        nextLink = GetNextLink(Source),
        #"Converted to Table" = Table.FromList(data, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
        #"Expanded Column1" = Table.ExpandRecordColumn(#"Converted to Table", "Column1", {"type", "id", "attributes", "relationships"}, {"type", "id", "attributes", "relationships"}),
        #"Expanded attributes" = Table.ExpandRecordColumn(#"Expanded Column1", "attributes", {"status", "rawText", "description", "message", "isCategorizable", "holdInfo", "roundUp", "cashback", "amount", "foreignAmount", "settledAt", "createdAt"}, {"attributes.status", "attributes.rawText", "attributes.description", "attributes.message", "attributes.isCategorizable", "attributes.holdInfo", "attributes.roundUp", "attributes.cashback", "attributes.amount", "attributes.foreignAmount", "attributes.settledAt", "attributes.createdAt"}),
        #"Expanded attributes.holdInfo" = Table.ExpandRecordColumn(#"Expanded attributes", "attributes.holdInfo", {"amount", "foreignAmount"}, {"attributes.holdInfo.amount", "attributes.holdInfo.foreignAmount"}),
        #"Expanded attributes.holdInfo.amount" = Table.ExpandRecordColumn(#"Expanded attributes.holdInfo", "attributes.holdInfo.amount", {"currencyCode", "value", "valueInBaseUnits"}, {"attributes.holdInfo.amount.currencyCode", "attributes.holdInfo.amount.value", "attributes.holdInfo.amount.valueInBaseUnits"}),
        #"Expanded attributes.holdInfo.foreignAmount" = Table.ExpandRecordColumn(#"Expanded attributes.holdInfo.amount", "attributes.holdInfo.foreignAmount", {"currencyCode", "value", "valueInBaseUnits"}, {"attributes.holdInfo.foreignAmount.currencyCode", "attributes.holdInfo.foreignAmount.value", "attributes.holdInfo.foreignAmount.valueInBaseUnits"}),
        #"Expanded attributes.roundUp" = Table.ExpandRecordColumn(#"Expanded attributes.holdInfo.foreignAmount", "attributes.roundUp", {"amount", "boostPortion"}, {"attributes.roundUp.amount", "attributes.roundUp.boostPortion"}),
        #"Expanded attributes.roundUp.amount" = Table.ExpandRecordColumn(#"Expanded attributes.roundUp", "attributes.roundUp.amount", {"currencyCode", "value", "valueInBaseUnits"}, {"attributes.roundUp.amount.currencyCode", "attributes.roundUp.amount.value", "attributes.roundUp.amount.valueInBaseUnits"}),
        #"Expanded attributes.roundUp.boostPortion" = Table.ExpandRecordColumn(#"Expanded attributes.roundUp.amount", "attributes.roundUp.boostPortion", {"currencyCode", "value", "valueInBaseUnits"}, {"attributes.roundUp.boostPortion.currencyCode", "attributes.roundUp.boostPortion.value", "attributes.roundUp.boostPortion.valueInBaseUnits"}),
        #"Expanded attributes.cashback" = Table.ExpandRecordColumn(#"Expanded attributes.roundUp.boostPortion", "attributes.cashback", {"description", "amount"}, {"attributes.cashback.description", "attributes.cashback.amount"}),
        #"Expanded attributes.cashback.amount" = Table.ExpandRecordColumn(#"Expanded attributes.cashback", "attributes.cashback.amount", {"currencyCode", "value", "valueInBaseUnits"}, {"attributes.cashback.amount.currencyCode", "attributes.cashback.amount.value", "attributes.cashback.amount.valueInBaseUnits"}),
        #"Expanded attributes.amount" = Table.ExpandRecordColumn(#"Expanded attributes.cashback.amount", "attributes.amount", {"currencyCode", "value", "valueInBaseUnits"}, {"attributes.amount.currencyCode", "attributes.amount.value", "attributes.amount.valueInBaseUnits"}),
        #"Expanded attributes.foreignAmount" = Table.ExpandRecordColumn(#"Expanded attributes.amount", "attributes.foreignAmount", {"currencyCode", "value", "valueInBaseUnits"}, {"attributes.foreignAmount.currencyCode", "attributes.foreignAmount.value", "attributes.foreignAmount.valueInBaseUnits"}),
        #"Expanded relationships" = Table.ExpandRecordColumn(#"Expanded attributes.foreignAmount", "relationships", {"account", "transferAccount", "category", "parentCategory", "tags"}, {"relationships.account", "relationships.transferAccount", "relationships.category", "relationships.parentCategory", "relationships.tags"}),
        #"Expanded relationships.account" = Table.ExpandRecordColumn(#"Expanded relationships", "relationships.account", {"data"}, {"relationships.account.data"}),
        #"Expanded relationships.account.data" = Table.ExpandRecordColumn(#"Expanded relationships.account", "relationships.account.data", {"id"}, {"relationships.account.data.id"}),
        #"Expanded relationships.transferAccount" = Table.ExpandRecordColumn(#"Expanded relationships.account.data", "relationships.transferAccount", {"data"}, {"relationships.transferAccount.data"}),
        #"Expanded relationships.transferAccount.data" = Table.ExpandRecordColumn(#"Expanded relationships.transferAccount", "relationships.transferAccount.data", {"id"}, {"relationships.transferAccount.data.id"}),
        #"Expanded relationships.category" = Table.ExpandRecordColumn(#"Expanded relationships.transferAccount.data", "relationships.category", {"data"}, {"relationships.category.data"}),
        #"Expanded relationships.category.data" = Table.ExpandRecordColumn(#"Expanded relationships.category", "relationships.category.data", {"id"}, {"relationships.category.data.id"}),
        #"Expanded relationships.parentCategory" = Table.ExpandRecordColumn(#"Expanded relationships.category.data", "relationships.parentCategory", {"data"}, {"relationships.parentCategory.data"}),
        #"Expanded relationships.parentCategory.data" = Table.ExpandRecordColumn(#"Expanded relationships.parentCategory", "relationships.parentCategory.data", {"id"}, {"relationships.parentCategory.data.id"}),
        #"Expanded relationships.tags" = Table.ExpandRecordColumn(#"Expanded relationships.parentCategory.data", "relationships.tags", {"data"}, {"relationships.tags.data"}),
        #"Added Custom" = Table.AddColumn(#"Expanded relationships.tags", "relationships.tags.data.tags", each let typeList = [relationships.tags.data], typeCount = List.Count([relationships.tags.data]) in Text.Combine(List.Transform(List.Numbers(0, typeCount, 1), each Record.Field(typeList{_},"id")), ", ")),
        #"Removed Columns" = Table.RemoveColumns(#"Added Custom",{"relationships.tags.data"}),
        #"Replaced Value" = Table.ReplaceValue(#"Removed Columns","",null,Replacer.ReplaceValue,{"relationships.tags.data.tags"}),
        #"Changed Type" = Table.TransformColumnTypes(#"Replaced Value",{{"type", type text}, {"id", type text}, {"attributes.status", type text}, {"attributes.rawText", type text}, {"attributes.description", type text}, {"attributes.message", type text}, {"attributes.isCategorizable", type logical}, {"attributes.holdInfo.amount.currencyCode", type text}, {"attributes.holdInfo.amount.value", Currency.Type}, {"attributes.holdInfo.amount.valueInBaseUnits", Int64.Type}, {"attributes.holdInfo.foreignAmount.currencyCode", type text}, {"attributes.holdInfo.foreignAmount.value", Currency.Type}, {"attributes.holdInfo.foreignAmount.valueInBaseUnits", Int64.Type}, {"attributes.roundUp.amount.currencyCode", type text}, {"attributes.roundUp.amount.value", Currency.Type}, {"attributes.roundUp.amount.valueInBaseUnits", Int64.Type}, {"attributes.roundUp.boostPortion.currencyCode", type text}, {"attributes.roundUp.boostPortion.value", Currency.Type}, {"attributes.roundUp.boostPortion.valueInBaseUnits", Int64.Type}, {"attributes.cashback.description", type text}, {"attributes.cashback.amount.currencyCode", type text}, {"attributes.cashback.amount.value", Currency.Type}, {"attributes.cashback.amount.valueInBaseUnits", Int64.Type}, {"attributes.amount.currencyCode", type text}, {"attributes.amount.value", Currency.Type}, {"attributes.amount.valueInBaseUnits", Int64.Type}, {"attributes.foreignAmount.currencyCode", type text}, {"attributes.foreignAmount.value", Currency.Type}, {"attributes.foreignAmount.valueInBaseUnits", Int64.Type}, {"attributes.settledAt", type datetimezone}, {"attributes.createdAt", type datetimezone}, {"relationships.account.data.id", type text}, {"relationships.transferAccount.data.id", type text}, {"relationships.category.data.id", type text}, {"relationships.parentCategory.data.id", type text}, {"relationships.tags.data.tags", type text}})
    in
        #"Changed Type" meta [NextLink = nextLink];

UPBankAPI.Transactions = () => Table.GetAllPagesByNextLink(BaseUrl & "transactions", GetTransactionPage);

GetAccountPage = (url as text) =>
    let
        Source = Json.Document(Web.Contents(url, [Headers=DefaultRequestHeaders])),
        data = Source[data],
        nextLink = GetNextLink(Source),
        #"Converted to Table" = Table.FromList(data, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
        #"Expanded Column1" = Table.ExpandRecordColumn(#"Converted to Table", "Column1", {"type", "id", "attributes", "relationships", "links"}, {"type", "id", "attributes", "relationships", "links"}),
        #"Expanded attributes" = Table.ExpandRecordColumn(#"Expanded Column1", "attributes", {"displayName", "accountType", "ownershipType", "balance", "createdAt"}, {"attributes.displayName", "attributes.accountType", "attributes.ownershipType", "attributes.balance", "attributes.createdAt"}),
        #"Expanded attributes.balance" = Table.ExpandRecordColumn(#"Expanded attributes", "attributes.balance", {"currencyCode", "value", "valueInBaseUnits"}, {"attributes.balance.currencyCode", "attributes.balance.value", "attributes.balance.valueInBaseUnits"}),
        #"Expanded relationships" = Table.ExpandRecordColumn(#"Expanded attributes.balance", "relationships", {"transactions"}, {"relationships.transactions"}),
        #"Expanded relationships.transactions" = Table.ExpandRecordColumn(#"Expanded relationships", "relationships.transactions", {"links"}, {"relationships.transactions.links"}),
        #"Expanded relationships.transactions.links" = Table.ExpandRecordColumn(#"Expanded relationships.transactions", "relationships.transactions.links", {"related"}, {"relationships.transactions.links.related"}),
        #"Expanded links" = Table.ExpandRecordColumn(#"Expanded relationships.transactions.links", "links", {"self"}, {"links.self"}),
        #"Changed Type" = Table.TransformColumnTypes(#"Expanded links",{{"attributes.balance.value", Currency.Type}, {"attributes.balance.valueInBaseUnits", Int64.Type}, {"attributes.createdAt", type datetimezone}, {"type", type text}, {"id", type text}, {"attributes.displayName", type text}, {"attributes.accountType", type text}, {"attributes.ownershipType", type text}, {"attributes.balance.currencyCode", type text}, {"relationships.transactions.links.related", type text}, {"links.self", type text}})
    in
        #"Changed Type" meta [NextLink = nextLink];

UPBankAPI.Accounts = () => Table.GetAllPagesByNextLink(BaseUrl & "accounts", GetAccountPage);

//-- Navigation table --//

UPBankNavTable = () as table =>
    let
        Source = #table({"Name", "Data", "ItemKind", "ItemName", "IsLeaf"}, {
            {"Accounts", UPBankAPI.Accounts(), "Table", "Table", true},
            {"Transactions", UPBankAPI.Transactions(), "Table", "Table", true},
            {"Categories", UPBankAPI.Categories(), "Table", "Table", true},
            {"Tags", UPBankAPI.Tags(), "Table", "Table", true},
            {"Ping", UPBankAPI.Ping(), "Table", "Table", true}
        }),
        navTable = Table.ToNavigationTable(Source, {"Name"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        navTable;

[DataSource.Kind="UPBankAPI", Publish="UPBankAPI.Publish"]
shared UPBankAPI.Contents =  UPBankNavTable;

