-- CRM Database Schema for BionicPRO
-- Assignment 4: CDC with Debezium

-- Create customers table
CREATE TABLE IF NOT EXISTS public.customers (
    customer_id SERIAL PRIMARY KEY,
    username VARCHAR(100) UNIQUE NOT NULL,
    full_name VARCHAR(255) NOT NULL,
    email VARCHAR(255) NOT NULL,
    phone VARCHAR(50),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create prostheses table
CREATE TABLE IF NOT EXISTS public.prostheses (
    prosthesis_id VARCHAR(50) PRIMARY KEY,
    customer_id INTEGER REFERENCES public.customers(customer_id),
    model VARCHAR(100) NOT NULL,
    manufacture_date DATE NOT NULL,
    status VARCHAR(50) DEFAULT 'active',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create orders table (for billing/transactions)
CREATE TABLE IF NOT EXISTS public.orders (
    order_id SERIAL PRIMARY KEY,
    customer_id INTEGER REFERENCES public.customers(customer_id),
    prosthesis_id VARCHAR(50) REFERENCES public.prostheses(prosthesis_id),
    order_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    amount DECIMAL(10, 2) NOT NULL,
    status VARCHAR(50) DEFAULT 'pending',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Set REPLICA IDENTITY to FULL for CDC (Debezium requirement)
-- This ensures that all columns are included in UPDATE/DELETE events
ALTER TABLE public.customers REPLICA IDENTITY FULL;
ALTER TABLE public.prostheses REPLICA IDENTITY FULL;
ALTER TABLE public.orders REPLICA IDENTITY FULL;

-- Create indexes for performance
CREATE INDEX idx_prostheses_customer_id ON public.prostheses(customer_id);
CREATE INDEX idx_orders_customer_id ON public.orders(customer_id);
CREATE INDEX idx_orders_prosthesis_id ON public.orders(prosthesis_id);
CREATE INDEX idx_customers_username ON public.customers(username);

