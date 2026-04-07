import csv

input_file = "seeds/ecommerce_dataset_updated.csv"
output_file = "seeds/ecommerce_dataset_updated_clean.csv"

with open(input_file, newline='', encoding='utf-8') as infile, \
     open(output_file, 'w', newline='', encoding='utf-8') as outfile:

    reader = csv.reader(infile)
    writer = csv.writer(outfile)

    header = next(reader)

    # sanitize column names
    clean_header = [
        col.replace(" (%)", "_pct")
           .replace("(", "")
           .replace(")", "")
           .replace(" ", "_")
        for col in header
    ]

    writer.writerow(clean_header)

    for row in reader:
        writer.writerow(row)