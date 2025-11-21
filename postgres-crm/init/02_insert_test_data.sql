-- Test Data for CRM Database
-- Assignment 4: CDC with Debezium

-- Insert customers (matching LDAP users)
INSERT INTO public.customers (username, full_name, email, phone, created_at) VALUES
    ('john.doe', 'John Doe', 'john@example.com', '+1-555-0101', '2024-06-01 10:00:00'),
    ('jane.smith', 'Jane Smith', 'jane@example.com', '+1-555-0102', '2024-07-01 11:00:00'),
    ('alex.johnson', 'Alex Johnson', 'alex@example.com', '+1-555-0103', '2024-08-01 12:00:00')
ON CONFLICT (username) DO NOTHING;

-- Insert prostheses
INSERT INTO public.prostheses (prosthesis_id, customer_id, model, manufacture_date, status, created_at) VALUES
    ('BP-12345', 1, 'BionicArm Pro X1', '2024-06-15', 'active', '2024-06-15 09:00:00'),
    ('BP-23456', 2, 'BionicHand Elite', '2024-07-20', 'active', '2024-07-20 10:00:00'),
    ('BP-34567', 3, 'BionicArm Pro X2', '2024-08-10', 'active', '2024-08-10 11:00:00')
ON CONFLICT (prosthesis_id) DO NOTHING;

-- Insert orders (purchase history)
INSERT INTO public.orders (customer_id, prosthesis_id, order_date, amount, status) VALUES
    (1, 'BP-12345', '2024-06-15 14:00:00', 45000.00, 'completed'),
    (2, 'BP-23456', '2024-07-20 15:00:00', 42000.00, 'completed'),
    (3, 'BP-34567', '2024-08-10 16:00:00', 47000.00, 'completed');

-- Create a function to automatically update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create triggers for auto-updating updated_at
CREATE TRIGGER update_customers_updated_at
    BEFORE UPDATE ON public.customers
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_prostheses_updated_at
    BEFORE UPDATE ON public.prostheses
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_orders_updated_at
    BEFORE UPDATE ON public.orders
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

