import pandas as pd
import os
import glob

remitter_path = os.path.expanduser("~/Desktop/UPI Reliability Project/Remitter_Raw")
beneficiary_path = os.path.expanduser("~/Desktop/UPI Reliability Project/Beneficiary_Raw")
output_path = os.path.expanduser("~/Desktop/UPI Reliability Project/Master_Data.xlsx")
output_csv_path = os.path.expanduser("~/Desktop/UPI Reliability Project/Master_Data.csv")

month_map = {
    'Jan': 1, 'Feb': 2, 'Mar': 3, 'Apr': 4,
    'May': 5, 'Jun': 6, 'Jul': 7, 'Aug': 8,
    'Sep': 9, 'Oct': 10, 'Nov': 11, 'Dec': 12
}

all_data = []

def clean_pct(val):
    if isinstance(val, str):
        return float(val.replace('%', '').strip())
    if pd.notna(val):
        v = float(val)
        # If float is below 1.0 it is in decimal form (e.g. 0.0084 = 0.84%)
        # Multiply by 100 to convert to percentage form
        # This handles Jan-Jul 2025 where NPCI stored values as decimals not strings
        return v * 100 if v < 1.0 else v
    return None

def process_file(filepath, role):
    filename = os.path.basename(filepath)
    
    if filename.startswith('~$'):
        return

    parts = filename.replace('.xlsx', '').split('-')
    year = None
    month = None
    for part in parts:
        if part.isdigit() and len(part) == 4:
            year = int(part)
        if part in month_map:
            month = month_map[part]

    if year is None or month is None:
        print(f"SKIPPED - could not parse date: {filename}")
        return

    try:
        df = pd.read_excel(filepath, header=1)
        df.columns = df.columns.str.strip()
        lower_cols = {col.lower().replace(' ', '_'): col for col in df.columns}

        bank_col = next((lower_cols[c] for c in lower_cols if 'bank' in c or 'member' in c), None)
        vol_col = next((lower_cols[c] for c in lower_cols if 'volume' in c), None)
        app_col = next((lower_cols[c] for c in lower_cols if 'approved' in c and 'deemed' not in c), None)
        bd_col = next((lower_cols[c] for c in lower_cols if c.startswith('bd')), None)
        td_col = next((lower_cols[c] for c in lower_cols if c.startswith('td')), None)

        if not all([bank_col, vol_col, app_col, bd_col, td_col]):
            print(f"SKIPPED - missing columns in: {filename}")
            print(f"  Columns found: {list(df.columns)}")
            return

        df = df[df[bank_col].notna()]
        df = df[df[bank_col].astype(str).str.strip() != '']

        for _, row in df.iterrows():
            bank_name = str(row[bank_col]).strip()
            if bank_name in ['nan', '']:
                continue
            all_data.append({
                'Month': month,
                'Year': year,
                'Bank_Name': bank_name,
                'Role': role,
                'Total_Volume_Mn': pd.to_numeric(str(row[vol_col]).replace(',', ''), errors='coerce'),
                'Approved_Pct': clean_pct(row[app_col]),
                'BD_Pct': clean_pct(row[bd_col]),
                'TD_Pct': clean_pct(row[td_col])
            })

        print(f"OK - {filename} | {len(df)} banks")

    except Exception as e:
        print(f"ERROR - {filename}: {e}")

print("Processing Remitter files...")
for f in sorted(glob.glob(os.path.join(remitter_path, "*.xlsx"))):
    process_file(f, "Remitter")

print("\nProcessing Beneficiary files...")
for f in sorted(glob.glob(os.path.join(beneficiary_path, "*.xlsx"))):
    process_file(f, "Beneficiary")

if all_data:
    master_df = pd.DataFrame(all_data)
    master_df = master_df.sort_values(['Year', 'Month', 'Role', 'Bank_Name'])
    master_df.to_excel(output_path, index=False)
    master_df.to_csv(output_csv_path, index=False)
    print(f"\nDONE. Total rows: {len(master_df)}")
    print(f"Saved to: {output_path}")
    print(f"Also saved CSV to: {output_csv_path}")
    
    # Verification check - print SBI Jan-Jul 2025 values to confirm fix
    print("\n=== VERIFICATION: SBI Remitter TD values ===")
    check = master_df[
        (master_df['Bank_Name'].str.contains('State Bank', case=False)) & 
        (master_df['Role'] == 'Remitter') &
        (master_df['Year'] == 2025)
    ][['Month', 'Year', 'TD_Pct', 'Approved_Pct']].sort_values('Month')
    print(check.to_string())
    print("\nAll 2025 TD values should be in 0.1 to 1.5 range, not 0.001 to 0.01")
else:
    print("No data collected.")
