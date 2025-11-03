# Module 3: KQL Queries and Real-Time Analytics

**Estimated Time:** 75 minutes  
**Difficulty:** Intermediate

## 📚 Learning Objectives

By the end of this module, you will be able to:

- ✅ Write basic and advanced KQL queries for SAP IDoc analysis
- ✅ Perform time-series analysis on streaming data
- ✅ Create aggregations and summaries for business insights
- ✅ Build real-time dashboards with KQL
- ✅ Optimize queries for performance
- ✅ Detect anomalies and monitor data quality

## 📋 Prerequisites

- Modules 1-2 completed
- Data flowing through Event Hub to Eventhouse
- Access to Fabric workspace with KQL Database
- Basic understanding of SQL concepts (helpful but not required)

---

## 🎯 Introduction to KQL

**Kusto Query Language (KQL)** is a powerful query language designed for analyzing large volumes of structured, semi-structured, and unstructured data. In Microsoft Fabric Real-Time Intelligence, KQL enables you to query streaming data with sub-second latency.

### Why KQL for Real-Time Analytics?

- **Optimized for Time-Series Data**: Built-in functions for temporal analysis
- **High Performance**: Processes millions of records in seconds
- **Rich Visualization**: Native support for charts and dashboards
- **Easy to Learn**: SQL-like syntax with powerful operators

### Query Structure

A typical KQL query follows this pattern:

```kql
TableName
| where condition
| extend new_column = expression
| summarize aggregation by grouping_column
| order by column
| project selected_columns
```

**Key Operators:**
- `where`: Filter rows
- `extend`: Add calculated columns
- `summarize`: Aggregate data
- `project`: Select specific columns
- `order by`: Sort results
- `render`: Visualize data

---

## 📊 Section 1: Basic Data Exploration

### Business Context

Before analyzing SAP IDoc data, you need to understand what data you have, its structure, and volume. These foundational queries help you explore your data landscape.

### Query 1.1: Count Total Messages

**Purpose:** Get a quick count of all IDoc messages in the database.

```kql
// Count all IDoc messages received
idoc_raw
| count
```

**Expected Result:** A single number showing total message count (e.g., 15,427)

**Business Value:** Understand the volume of data being processed.

---

### Query 1.2: Display Recent Messages

**Purpose:** View the most recent IDoc messages with key fields.

```kql
// Display the 10 most recent IDocs received
idoc_raw
| take 10
| order by timestamp desc
| project timestamp, idoc_type, message_type, sap_system, docnum=control.docnum
```

**Explanation:**
- `take 10`: Limit to 10 records (faster than `top`)
- `order by timestamp desc`: Sort newest first
- `project`: Select only the columns we need

**Expected Result:** Table with 10 rows showing latest messages

**💡 Tip:** Use `take` instead of `top` when you don't need a specific order—it's much faster!

---

### Query 1.3: Data Time Range

**Purpose:** Determine the time span of your data.

```kql
// Find first and last message received
idoc_raw
| summarize 
    First_Message = min(todatetime(timestamp)),
    Last_Message = max(todatetime(timestamp)),
    Total_Messages = count()
```

**Explanation:**
- `todatetime()`: Converts timestamp to datetime type
- `min()` / `max()`: Find earliest and latest timestamps
- `count()`: Total number of records

**Business Value:** Validate data ingestion and identify gaps.

**Expected Result:**
```
First_Message         Last_Message          Total_Messages
2024-11-01 08:00:00   2024-11-03 10:00:00   15,427
```

---

### Query 1.4: Unique IDoc Types

**Purpose:** Discover what types of business documents are in your data.

```kql
// List all unique IDoc types with counts
idoc_raw
| summarize Count = count() by message_type
| order by Count desc
```

**Business Value:** Understand the distribution of business transactions (orders, invoices, shipments, etc.)

**Expected Result:**
```
message_type    Count
ORDERS05        5,234
SHPMNT01        4,892
INVOIC02        3,456
DESADV01        1,845
```

---

## ⏱️ Section 2: Time-Series Analysis

### Business Context

In logistics and supply chain operations, understanding patterns over time is crucial. These queries help you identify trends, peak hours, and operational patterns.

### Query 2.1: Messages Per Hour (Last 24 Hours)

**Purpose:** Visualize message volume over time to identify patterns.

```kql
// Message volume by hour for the last 24 hours
idoc_raw
| where timestamp > ago(24h)
| summarize count() by bin(timestamp, 1h)
| render timechart
```

**Explanation:**
- `ago(24h)`: Dynamic time filter (last 24 hours)
- `bin(timestamp, 1h)`: Group timestamps into 1-hour buckets
- `render timechart`: Create a time-series chart

**Business Value:** Identify peak processing times and capacity planning needs.

**💡 Optimization Tip:** Use `ago()` instead of hard-coded dates for dynamic dashboards.

---

### Query 2.2: Message Rate (Messages/Minute)

**Purpose:** Calculate real-time throughput for monitoring.

```kql
// Calculate message processing rate per minute
idoc_raw
| where timestamp > ago(1h)
| summarize Messages = count() by bin(timestamp, 1m)
| extend Messages_Per_Minute = Messages
| render timechart
```

**Business Value:** Monitor system throughput and detect processing slowdowns.

**Expected Result:** Line chart showing messages/minute over the last hour

---

### Query 2.3: Peak Hours Analysis

**Purpose:** Identify which hours of the day have the highest activity.

```kql
// Identify peak activity hours
idoc_raw
| extend Hour = hourofday(todatetime(timestamp))
| summarize Total = count() by Hour
| order by Hour asc
| render columnchart
```

**Explanation:**
- `hourofday()`: Extracts hour (0-23) from datetime
- Aggregates all days together to show typical hourly pattern

**Business Value:** Schedule batch jobs during low-activity periods.

**Expected Result:** Column chart showing message volume by hour (0-23)

---

### Query 2.4: Activity by Day of Week

**Purpose:** Understand weekly patterns in business operations.

```kql
// Analyze activity patterns by day of week
idoc_raw
| extend DayNum = dayofweek(todatetime(timestamp))
| summarize Total = count() by DayNum
| extend Day_Name = case(
    DayNum == 0d, "Sunday",
    DayNum == 1d, "Monday",
    DayNum == 2d, "Tuesday",
    DayNum == 3d, "Wednesday",
    DayNum == 4d, "Thursday",
    DayNum == 5d, "Friday",
    DayNum == 6d, "Saturday",
    "Unknown"
)
| project Day_Name, Total
| order by DayNum asc
```

**Business Value:** Identify weekday vs. weekend patterns, plan maintenance windows.

**💡 Tip:** Business operations often show clear weekly patterns—use this to validate data quality!

---

## 📈 Section 3: Aggregations and Grouping

### Business Context

Aggregations transform raw transaction data into business insights. These queries help you understand document type distribution and categorize your data.

### Query 3.1: Message Type Distribution

**Purpose:** Visualize the proportion of different business document types.

```kql
// Visualize distribution of IDoc types
idoc_raw
| summarize count() by message_type
| render piechart
```

**Business Value:** Understand which business processes generate the most transactions.

**Expected Result:** Pie chart showing percentage breakdown by message type

---

### Query 3.2: Top 5 Most Frequent Types

**Purpose:** Identify the highest-volume transaction types.

```kql
// Top 5 message types by volume
idoc_raw
| summarize Total = count() by message_type
| top 5 by Total desc
| render columnchart
```

**Business Value:** Focus optimization efforts on high-volume transaction types.

---

### Query 3.3: Business Process Categorization

**Purpose:** Group related IDoc types into business process categories.

```kql
// Categorize messages by business process
idoc_raw
| summarize count() by 
    Category = case(
        message_type startswith "ORDERS", "Orders",
        message_type startswith "INVOIC", "Invoices",
        message_type startswith "WHSCON", "Warehouse Operations",
        message_type startswith "DESADV", "Delivery Advices",
        message_type startswith "SHPMNT", "Shipments",
        "Other"
    )
| render piechart
```

**Explanation:**
- `startswith`: Pattern matching for message types
- `case()`: Multi-condition logic (like SQL CASE WHEN)

**Business Value:** High-level view of business operations distribution.

---

### Query 3.4: Multi-Dimensional Aggregation

**Purpose:** Analyze volume by both time and message type.

```kql
// Message volume by type and hour
idoc_raw
| where timestamp > ago(7d)
| summarize Count = count() 
    by 
    message_type, 
    Hour = bin(timestamp, 1h)
| order by Hour desc, Count desc
| take 50
```

**Business Value:** Identify patterns like "order spike on Monday mornings."

---

## 🔍 Section 4: Filtering and Advanced Queries

### Business Context

In a 3PL environment, you often need to filter data for specific partners, time periods, or business rules. These queries demonstrate advanced filtering techniques.

### Query 4.1: Filter by SAP System

**Purpose:** Analyze data from a specific SAP system or environment.

```kql
// Messages from production SAP system
idoc_raw
| where sap_system == "PRD"
| summarize count() by message_type
| render piechart
```

**Business Value:** Compare production vs. test/dev environments.

---

### Query 4.2: Filter by Time Range and Type

**Purpose:** Analyze specific document types within a time window.

```kql
// Orders from the last 7 days
idoc_raw
| where timestamp > ago(7d)
| where message_type startswith "ORDERS"
| summarize 
    Total_Orders = count(),
    Systems = dcount(sap_system)
| extend Orders_Per_Day = Total_Orders / 7
```

**Explanation:**
- `dcount()`: Count distinct values (unique SAP systems)
- `extend`: Add calculated field

**Business Value:** Track order volume trends and system distribution.

---

### Query 4.3: Complex Filtering with Multiple Conditions

**Purpose:** Apply business logic to filter messages.

```kql
// High-priority orders from the last 24 hours
idoc_raw
| where timestamp > ago(24h)
| where message_type == "ORDERS05"
| where control.status == "03"  // Status 03 = Successfully processed
| project 
    timestamp,
    Order_Number = control.docnum,
    SAP_System = sap_system,
    Status = control.status
| order by timestamp desc
```

**Business Value:** Monitor critical transactions requiring immediate attention.

---

### Query 4.4: Join Concept (Using Let)

**Purpose:** Combine data from different time periods for comparison.

```kql
// Compare current week vs. previous week
let current_week = idoc_raw 
    | where timestamp > ago(7d) 
    | count 
    | project Current = Count;

let previous_week = idoc_raw 
    | where timestamp between (ago(14d) .. ago(7d)) 
    | count 
    | project Previous = Count;

current_week
| extend Previous = toscalar(previous_week)
| extend Change_Percent = round((todouble(Current - Previous) / Previous) * 100, 2)
| project Current, Previous, Change_Percent
```

**Explanation:**
- `let`: Define reusable query fragments
- `toscalar()`: Convert single-value result to scalar
- `between`: Range filter

**Business Value:** Week-over-week growth analysis.

**💡 Advanced Tip:** Use `let` statements to break complex queries into readable parts!

---

## 📊 Section 5: Performance Monitoring

### Business Context

Monitoring the performance of your data pipeline is critical. These queries help you track ingestion latency, message sizes, and system health.

### Query 5.1: Ingestion Latency Analysis

**Purpose:** Measure time between message creation and ingestion into Fabric.

```kql
// Calculate ingestion latency metrics
idoc_raw
| where timestamp > ago(1h)
| extend ingestion_time = ingestion_time()
| extend latency_seconds = datetime_diff('second', ingestion_time, todatetime(timestamp))
| summarize 
    Average_Latency = avg(latency_seconds),
    P50_Latency = percentile(latency_seconds, 50),
    P95_Latency = percentile(latency_seconds, 95),
    P99_Latency = percentile(latency_seconds, 99),
    Max_Latency = max(latency_seconds)
```

**Explanation:**
- `ingestion_time()`: Built-in function for when data was ingested
- `datetime_diff()`: Calculate time difference
- `percentile()`: Statistical distribution (P95 = 95% of values are below this)

**Business Value:** Ensure SLA compliance for real-time data delivery.

**Expected Result:**
```
Average_Latency  P50_Latency  P95_Latency  P99_Latency  Max_Latency
15.3             12.0         28.5         45.2         120.0
```

**💡 Performance Tip:** Monitor P95 and P99 latencies, not just averages—they reveal outliers!

---

### Query 5.2: Latency by Message Type

**Purpose:** Identify which message types have processing delays.

```kql
// Compare latency across message types
idoc_raw
| where timestamp > ago(1h)
| extend ingestion_time = ingestion_time()
| extend latency_seconds = datetime_diff('second', ingestion_time, todatetime(timestamp))
| summarize Average_Latency = avg(latency_seconds) by message_type
| order by Average_Latency desc
| render barchart
```

**Business Value:** Optimize processing for high-latency message types.

---

### Query 5.3: Message Size Statistics

**Purpose:** Understand data volume and storage implications.

```kql
// Analyze message sizes by type
idoc_raw
| extend message_size = estimate_data_size(data)
| summarize 
    Avg_Size_KB = avg(message_size) / 1024,
    Min_Size_KB = min(message_size) / 1024,
    Max_Size_KB = max(message_size) / 1024,
    Total_Size_MB = sum(message_size) / 1024 / 1024
    by message_type
| order by Avg_Size_KB desc
```

**Explanation:**
- `estimate_data_size()`: Calculates approximate size in bytes
- Division by 1024: Convert to KB/MB

**Business Value:** Capacity planning and storage cost optimization.

---

### Query 5.4: System Health Check

**Purpose:** Comprehensive health status of the ingestion pipeline.

```kql
// Real-time health check
let last_hour = idoc_raw | where timestamp > ago(1h);
last_hour
| summarize 
    Messages_Received = count(),
    Avg_Latency_Sec = avg(datetime_diff('second', ingestion_time(), todatetime(timestamp))),
    Different_Types = dcount(message_type),
    Active_Systems = dcount(sap_system),
    Last_Message = max(todatetime(timestamp))
| extend 
    Status = case(
        Messages_Received > 0 and Avg_Latency_Sec < 60, "✅ HEALTHY",
        Messages_Received > 0 and Avg_Latency_Sec < 300, "⚠️ DEGRADED",
        Messages_Received == 0, "❌ NO DATA",
        "⚠️ WARNING"
    )
```

**Business Value:** Real-time monitoring dashboard for operations.

**💡 Dashboard Tip:** Pin this query to your Fabric dashboard for continuous monitoring!

---

## 🚨 Section 6: Anomaly Detection

### Business Context

Detecting anomalies early prevents business disruptions. These queries help identify data quality issues, missing data, and unusual patterns.

### Query 6.1: Messages with Errors

**Purpose:** Identify failed or error-status IDoc messages.

```kql
// Find messages with error status
idoc_raw
| extend Status = tostring(control.status)
| where Status != "03"  // 03 = Success in SAP
| project 
    timestamp, 
    message_type, 
    Doc_Number = control.docnum,
    Status,
    sap_system
| order by timestamp desc
```

**Explanation:**
- SAP IDoc status codes: 03 = Success, others indicate errors
- Filter out successful messages to focus on issues

**Business Value:** Immediate visibility into processing failures.

---

### Query 6.2: Abnormal Message Volume Detection

**Purpose:** Detect unusual spikes in message volume.

```kql
// Detect message spikes (> 2x average)
let avgRate = toscalar(
    idoc_raw
    | where timestamp > ago(7d)
    | summarize count() by bin(timestamp, 1h)
    | summarize avg(count_)
);

idoc_raw
| where timestamp > ago(24h)
| summarize Messages = count() by bin(timestamp, 1h)
| where Messages > avgRate * 2
| project timestamp, Messages, Average = avgRate, Ratio = Messages / avgRate
| order by timestamp desc
```

**Explanation:**
- Calculate baseline (7-day average)
- Flag hours with >2x the average

**Business Value:** Detect data floods, system issues, or business events.

---

### Query 6.3: Identify Time Gaps

**Purpose:** Find periods with missing data.

```kql
// Identify periods without messages (potential data gaps)
idoc_raw
| where timestamp > ago(24h)
| make-series Messages = count() default = 0 on timestamp step 5m
| mv-expand timestamp, Messages
| where Messages == 0
| project timestamp
```

**Explanation:**
- `make-series`: Creates continuous time series
- `default = 0`: Fill gaps with zero
- `mv-expand`: Expand array to rows

**Business Value:** Detect integration failures or network issues.

**💡 Alerting Tip:** Set up Data Activator alerts on this query to get notified of gaps!

---

### Query 6.4: Suspicious Processing Delays

**Purpose:** Flag messages with unusually high latency.

```kql
// Messages with latency > 5 minutes
idoc_raw
| where timestamp > ago(1h)
| extend ingestion_time = ingestion_time()
| extend latency_minutes = datetime_diff('minute', ingestion_time, todatetime(timestamp))
| where latency_minutes > 5
| project timestamp, message_type, latency_minutes, docnum=control.docnum
| order by latency_minutes desc
```

**Business Value:** Identify integration bottlenecks requiring investigation.

---

## 📊 Advanced Topics

### Creating Reusable Functions

You can create KQL functions to encapsulate commonly used logic:

```kql
// Create a function to get recent IDocs
.create-or-alter function GetRecentIDocs(hours_back: int = 1) {
    idoc_raw
    | where timestamp > ago(hours_back * 1h)
    | order by timestamp desc
}

// Usage
GetRecentIDocs(24)
| take 100
```

### Working with Dynamic Data

IDoc messages contain nested JSON structures. Here's how to extract nested fields:

```kql
// Extract nested customer information from ORDERS
idoc_raw
| where message_type == "ORDERS05"
| extend 
    Order_Number = control.docnum,
    Customer_ID = tostring(data.E1EDK01[0].BELNR)
| take 10
```

### Materialized Views for Performance

For frequently-run queries, create materialized views:

```kql
.create async materialized-view OrdersSummary on table idoc_raw
{
    idoc_raw
    | where message_type startswith "ORDERS"
    | summarize 
        Total_Orders = count(),
        Avg_Processing_Time = avg(datetime_diff('second', ingestion_time(), timestamp))
        by bin(timestamp, 1h), sap_system
}
```

---

## 🎯 Query Optimization Tips

### 1. **Filter Early, Filter Often**

❌ **Bad:**
```kql
idoc_raw
| extend hour = hourofday(timestamp)
| summarize count() by message_type
| where hour > 8
```

✅ **Good:**
```kql
idoc_raw
| where hourofday(timestamp) > 8
| summarize count() by message_type
```

**Why:** Filtering before aggregation reduces data processed.

---

### 2. **Use `take` Instead of `top` for Random Samples**

❌ **Slower:**
```kql
idoc_raw | top 100 by timestamp
```

✅ **Faster:**
```kql
idoc_raw | take 100
```

**Why:** `take` doesn't need to sort the entire table.

---

### 3. **Limit Time Ranges**

❌ **Inefficient:**
```kql
idoc_raw | summarize count() by message_type
```

✅ **Efficient:**
```kql
idoc_raw
| where timestamp > ago(7d)
| summarize count() by message_type
```

**Why:** Reduces data scanned, especially in large datasets.

---

### 4. **Use `project` to Reduce Column Count**

❌ **Transfers more data:**
```kql
idoc_raw
| where timestamp > ago(1h)
| order by timestamp
```

✅ **Transfers less data:**
```kql
idoc_raw
| where timestamp > ago(1h)
| project timestamp, message_type, docnum=control.docnum
| order by timestamp
```

---

### 5. **Leverage Caching**

- Eventhouse caches hot data (recent time ranges)
- Repeated queries on the same time range are much faster
- Configure hot cache policy for your tables

---

## 🧪 Practice Exercises

Ready to test your skills? Head over to [KQL Practice Exercises](../exercises/kql-practice.md) for hands-on challenges!

---

## 📚 Additional Resources

### Microsoft Documentation
- [KQL Quick Reference](https://learn.microsoft.com/azure/data-explorer/kusto/query/kql-quick-reference)
- [KQL Best Practices](https://learn.microsoft.com/azure/data-explorer/kusto/query/best-practices)
- [Fabric Real-Time Intelligence](https://learn.microsoft.com/fabric/real-time-intelligence/)

### Query Samples
- [KQL Examples File](../queries/kql-examples.kql) - All queries from this module
- [Advanced Queries](../../fabric/README_KQL_QUERIES.md) - Production-ready queries

### Next Steps
- **Module 4**: [Lakehouse Medallion Architecture](./module4-lakehouse-layers.md)
- Build on KQL skills by transforming data into Silver and Gold layers

---

## ✅ Module 3 Checklist

Before moving to Module 4, ensure you can:

- [ ] Write basic KQL queries to explore IDoc data
- [ ] Create time-series visualizations with `render timechart`
- [ ] Calculate aggregations using `summarize`
- [ ] Filter data effectively with `where` and time ranges
- [ ] Monitor performance metrics (latency, throughput)
- [ ] Detect anomalies in message volume and latency
- [ ] Optimize queries using best practices
- [ ] Create reusable functions for common queries

---

## 🎉 Congratulations!

You've completed Module 3 and learned how to analyze real-time SAP IDoc data using KQL. You can now:

✅ Explore and understand your data  
✅ Create business insights through aggregations  
✅ Monitor system performance  
✅ Detect anomalies and data quality issues  
✅ Build real-time dashboards  

**Next:** Continue to [Module 4 - Lakehouse Medallion Architecture](./module4-lakehouse-layers.md) to transform this streaming data into curated business views!

---

**Questions or Issues?** Check the [Workshop README](../README.md) troubleshooting section or open a [GitHub Issue](https://github.com/flthibau/Fabric-SAP-Idocs/issues).
