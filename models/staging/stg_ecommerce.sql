with source as (

     select * from "dev"."main"."ecommerce_dataset_updated"

),

renamed as (

    select
        "User_ID"                       as user_id,
        "Product_ID"                    as product_id,
        "Category"                      as category,
        "Price (Rs.)"                   as price_usd,
        "Discount (%)"                  as discount_pct,
        "Final_Price(Rs.)"              as final_price_usd,
        "Payment_Method"                as payment_method,
        strptime("Purchase_Date", '%d-%m-%Y')::date   as purchase_date

    from source

)

select * from renamed