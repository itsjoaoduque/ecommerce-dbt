with source as (

     select * from {{ ref('ecommerce_dataset_updated_clean') }}

),

renamed as (

    select
        "User_ID"                       as user_id,
        "Product_ID"                    as product_id,
        "Category"                      as category,
        "Price_Rs."                     as price_usd,
        "Discount_pct"                  as discount_pct,
        "Final_PriceRs."                as final_price_usd,
        "Payment_Method"                as payment_method,
        {{ parse_date('"Purchase_Date"', '%d-%m-%Y') }}    as purchase_date

    from source

)

select * from renamed