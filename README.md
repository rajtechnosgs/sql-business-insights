# SQL Business Insights — Task 1

A 10-query business analytics SQL project built on a 10,000-customer / 40,000-order / 100,000-session e-commerce dataset (`ecom` schema). Each query answers a real business question (from CEO-level revenue summaries to marketing attribution), is sanity-checked, and interpreted in [`INTERPRETATIONS.md`](INTERPRETATIONS.md).

Full write-up with 5 key insights: **[What 10 SQL Queries Told Me About This Business](<PASTE YOUR notion.site LINK HERE>)**

Connect with me: [www.linkedin.com/in/raj-dev-63963a22b](https://www.linkedin.com/in/raj-dev-63963a22b)

## Database Schema

```mermaid
erDiagram
    customers          ||--o{ orders : places
    orders              ||--|{ order_items : contains
    order_items         }o--|| product_variants : ships
    product_variants    }o--|| products : sku_of
    products             }o--|| categories : in
    orders                ||--o{ payment_intents : pays_via
    payment_intents         ||--o{ payment_transactions : attempts
    payment_methods          ||--o{ payment_intents : used_in
    orders                    ||--o{ refunds : may_have
    orders                     ||--o{ return_requests : may_return
    return_requests              ||--|{ return_items : with
    orders                        ||--o{ shipments : ships
    customers                      ||--o{ sessions : starts
    sessions                        ||--o{ session_events : logs
    sessions                         ||--o{ attribution_touches : has
    attribution_touches               }o--o| attribution_campaigns : maps_via_bridge
    attribution_campaigns              }o--|| marketing_campaigns : refs
```

## Key Visuals

**Q2 — Monthly Signup Cohort Retention**
![Cohort Retention](screenshots/q2.webp)

**Q3 — Funnel Conversion by Acquisition Channel**
![Funnel Conversion](screenshots/Q3.webp)

**Q5 — Category Health: Purchases → Returns**
![Category Health](screenshots/q5.webp)

**Q6 — Payment Failure Analysis**
![Payment Failure](screenshots/Q6.webp)

**Q8 — Customer LTV + Bucket Share of Revenue**
![LTV Bucket Share](screenshots/q8.webp)

## Repo Structure
