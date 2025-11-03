# KQL Practice Exercises

**Module 3: Real-Time Analytics**

This file contains progressive hands-on exercises to reinforce your KQL skills. Each exercise builds on concepts from Module 3.

---

## 📋 How to Use This Guide

1. **Read the Exercise**: Understand what you need to accomplish
2. **Try It Yourself**: Write the query without looking at the solution
3. **Check Your Answer**: Compare with the provided solution
4. **Experiment**: Modify the query to deepen your understanding

---

## 🎯 Level 1: Beginner Exercises

These exercises focus on basic KQL syntax and fundamental operations.

### Exercise 1.1: Count Messages by SAP System

**Objective:** Count how many messages came from each SAP system.

**Requirements:**
- Use the `idoc_raw` table
- Group by `sap_system`
- Show the count for each system
- Order by count descending

**Expected Output:**
```
sap_system    Count
PRD           8,234
QAS           4,567
DEV           2,626
```

<details>
<summary>💡 Hint</summary>

Use `summarize` with `count()` and `by` clause.
</details>

<details>
<summary>✅ Solution</summary>

```kql
idoc_raw
| summarize Count = count() by sap_system
| order by Count desc
```
</details>

---

### Exercise 1.2: Find Messages from the Last 6 Hours

**Objective:** Retrieve all messages received in the last 6 hours.

**Requirements:**
- Filter by timestamp
- Show only: timestamp, message_type, and sap_system
- Order by timestamp descending

<details>
<summary>💡 Hint</summary>

Use `ago(6h)` in a `where` clause.
</details>

<details>
<summary>✅ Solution</summary>

```kql
idoc_raw
| where timestamp > ago(6h)
| project timestamp, message_type, sap_system
| order by timestamp desc
```
</details>

---

### Exercise 1.3: Count Distinct IDoc Types

**Objective:** Determine how many unique IDoc types exist in your data.

**Requirements:**
- Count distinct values of `idoc_type`
- Display as a single number

<details>
<summary>💡 Hint</summary>

Use `dcount()` for distinct count.
</details>

<details>
<summary>✅ Solution</summary>

```kql
idoc_raw
| summarize Distinct_IDoc_Types = dcount(idoc_type)
```
</details>

---

### Exercise 1.4: List Messages with Specific Type

**Objective:** Find all shipment (SHPMNT) messages from the last 24 hours.

**Requirements:**
- Filter by message_type starting with "SHPMNT"
- Filter by last 24 hours
- Display: timestamp, message_type, docnum from control
- Limit to 50 results

<details>
<summary>✅ Solution</summary>

```kql
idoc_raw
| where timestamp > ago(24h)
| where message_type startswith "SHPMNT"
| project timestamp, message_type, docnum=control.docnum
| take 50
```
</details>

---

## 🎯 Level 2: Intermediate Exercises

These exercises combine multiple operators and introduce calculations.

### Exercise 2.1: Hourly Message Rate Calculation

**Objective:** Calculate the average messages per hour over the last 7 days.

**Requirements:**
- Use last 7 days of data
- Group by 1-hour bins
- Calculate the average count across all hours

**Expected Output:**
```
Average_Messages_Per_Hour
412.5
```

<details>
<summary>💡 Hint</summary>

Use `bin()` to group by hour, then calculate average of the counts.
</details>

<details>
<summary>✅ Solution</summary>

```kql
idoc_raw
| where timestamp > ago(7d)
| summarize Count = count() by bin(timestamp, 1h)
| summarize Average_Messages_Per_Hour = avg(Count)
```
</details>

---

### Exercise 2.2: Business Hours Analysis

**Objective:** Count messages that arrived during business hours (9 AM - 5 PM).

**Requirements:**
- Filter for hours 9-17 (9 AM to 5 PM)
- Count total messages
- Calculate percentage of all messages

<details>
<summary>💡 Hint</summary>

Use `hourofday()` function and filter with `where`.
</details>

<details>
<summary>✅ Solution</summary>

```kql
let business_hours = idoc_raw
    | where hourofday(timestamp) >= 9 and hourofday(timestamp) < 17
    | count;

let total_messages = idoc_raw | count;

business_hours
| extend Total = toscalar(total_messages)
| extend Percent_Business_Hours = round(100.0 * todouble(Count) / todouble(Total), 2)
| project Messages_Business_Hours = Count, Total_Messages = Total, Percent_Business_Hours
```
</details>

---

### Exercise 2.3: Message Type Growth Trend

**Objective:** Compare message counts for each type between this week and last week.

**Requirements:**
- Calculate counts for current week (last 7 days)
- Calculate counts for previous week (8-14 days ago)
- Show growth percentage
- Order by current week count descending

<details>
<summary>✅ Solution</summary>

```kql
let current_week = idoc_raw
    | where timestamp > ago(7d)
    | summarize Current = count() by message_type;

let previous_week = idoc_raw
    | where timestamp between (ago(14d) .. ago(7d))
    | summarize Previous = count() by message_type;

current_week
| join kind=leftouter (previous_week) on message_type
| extend Previous = coalesce(Previous, 0)
| extend Growth_Percent = round((todouble(Current - Previous) / Previous) * 100, 2)
| project message_type, Current, Previous, Growth_Percent
| order by Current desc
```
</details>

---

### Exercise 2.4: Peak Hour Identification

**Objective:** Identify the hour with the highest message volume in the last 7 days.

**Requirements:**
- Group by hour of day (0-23)
- Find the hour with maximum messages
- Display the hour and count

<details>
<summary>✅ Solution</summary>

```kql
idoc_raw
| where timestamp > ago(7d)
| extend Hour = hourofday(timestamp)
| summarize Total = count() by Hour
| top 1 by Total desc
```
</details>

---

## 🎯 Level 3: Advanced Exercises

These exercises require complex logic, multiple steps, and advanced KQL features.

### Exercise 3.1: Latency Percentile Analysis by Type

**Objective:** Calculate P50, P95, and P99 latency for each message type.

**Requirements:**
- Use last 24 hours
- Calculate latency in seconds (ingestion_time - timestamp)
- Show percentiles for each message type
- Order by P95 latency descending

<details>
<summary>✅ Solution</summary>

```kql
idoc_raw
| where timestamp > ago(24h)
| extend latency_seconds = datetime_diff('second', ingestion_time(), todatetime(timestamp))
| summarize 
    P50 = percentile(latency_seconds, 50),
    P95 = percentile(latency_seconds, 95),
    P99 = percentile(latency_seconds, 99),
    Messages = count()
    by message_type
| order by P95 desc
```
</details>

---

### Exercise 3.2: Anomaly Detection - Volume Outliers

**Objective:** Identify days where message volume deviated significantly from the 7-day average.

**Requirements:**
- Group messages by day
- Calculate 7-day average
- Flag days with >150% or <50% of average
- Show deviation percentage

<details>
<summary>💡 Hint</summary>

Use `let` to store the average, then compare daily counts.
</details>

<details>
<summary>✅ Solution</summary>

```kql
let avg_daily = toscalar(
    idoc_raw
    | where timestamp > ago(7d)
    | summarize count()
    | extend avg = Count / 7
    | project avg
);

idoc_raw
| where timestamp > ago(7d)
| summarize Daily_Count = count() by Day = startofday(timestamp)
| extend Average = avg_daily
| extend Deviation_Percent = round((todouble(Daily_Count - Average) / Average) * 100, 2)
| where Deviation_Percent > 50 or Deviation_Percent < -50
| project Day, Daily_Count, Average, Deviation_Percent
| order by abs(Deviation_Percent) desc
```
</details>

---

### Exercise 3.3: Complex Business Rule - Late Orders

**Objective:** Find orders that were received more than 30 minutes after they were created in SAP, during business hours only.

**Requirements:**
- Focus on ORDERS message type
- Calculate time difference between timestamp and ingestion_time
- Filter for >30 minutes latency
- Only include business hours (9 AM - 5 PM)
- Show order number, latency in minutes, hour

<details>
<summary>✅ Solution</summary>

```kql
idoc_raw
| where message_type startswith "ORDERS"
| where hourofday(timestamp) >= 9 and hourofday(timestamp) < 17
| extend latency_minutes = datetime_diff('minute', ingestion_time(), todatetime(timestamp))
| where latency_minutes > 30
| project 
    timestamp,
    Order_Number = control.docnum,
    Latency_Minutes = latency_minutes,
    Hour = hourofday(timestamp)
| order by Latency_Minutes desc
```
</details>

---

### Exercise 3.4: Rolling Average Calculation

**Objective:** Calculate a 3-hour rolling average of message volume.

**Requirements:**
- Use last 24 hours
- Group by 1-hour bins
- Calculate rolling 3-hour average
- Visualize with timechart

<details>
<summary>💡 Hint</summary>

Use `make-series` with `moving_avg()` function.
</details>

<details>
<summary>✅ Solution</summary>

```kql
idoc_raw
| where timestamp > ago(24h)
| make-series Count=count() default=0 on timestamp step 1h
| extend Rolling_Avg_3h = series_moving_avg(Count, 3)
| mv-expand timestamp to typeof(datetime), Count to typeof(long), Rolling_Avg_3h to typeof(real)
| project timestamp, Count, Rolling_Avg_3h
| render timechart
```
</details>

---

### Exercise 3.5: Multi-Dimensional Analysis

**Objective:** Create a comprehensive summary showing message distribution by:
- Message type
- SAP system
- Hour of day

**Requirements:**
- Use last 7 days
- Group by all three dimensions
- Show top 20 combinations by count
- Include percentage of total

<details>
<summary>✅ Solution</summary>

```kql
let total = toscalar(idoc_raw | where timestamp > ago(7d) | count);

idoc_raw
| where timestamp > ago(7d)
| extend Hour = hourofday(timestamp)
| summarize Count = count() by message_type, sap_system, Hour
| extend Percent_of_Total = round(100.0 * todouble(Count) / todouble(total), 2)
| top 20 by Count desc
| project message_type, sap_system, Hour, Count, Percent_of_Total
```
</details>

---

## 🎯 Level 4: Expert Challenges

These exercises simulate real-world scenarios requiring creativity and advanced KQL knowledge.

### Challenge 4.1: Data Quality Dashboard

**Objective:** Create a comprehensive data quality report showing:
1. Total messages in last 24 hours
2. Messages with missing control data
3. Messages with error status (!= "03")
4. Messages with latency >5 minutes
5. Overall data quality score (percentage)

<details>
<summary>✅ Solution</summary>

```kql
let time_range = idoc_raw | where timestamp > ago(24h);

let total = toscalar(time_range | count);

let missing_control = toscalar(
    time_range 
    | where isnull(control) 
    | count
);

let error_status = toscalar(
    time_range 
    | where control.status != "03" 
    | count
);

let high_latency = toscalar(
    time_range 
    | extend latency = datetime_diff('minute', ingestion_time(), todatetime(timestamp))
    | where latency > 5
    | count
);

print 
    Total_Messages = total,
    Missing_Control = missing_control,
    Error_Status = error_status,
    High_Latency = high_latency,
    Total_Issues = missing_control + error_status + high_latency,
    Quality_Score = round(100.0 * (1 - todouble(missing_control + error_status + high_latency) / todouble(total)), 2)
```
</details>

---

### Challenge 4.2: Smart Alerting Query

**Objective:** Build a query that flags multiple anomaly conditions:
- Message volume spike (>3x average)
- Prolonged silence (>10 min with no messages)
- High error rate (>5% error status)
- Excessive latency (P95 >2 minutes)

Create a single query that checks all conditions and returns alerts.

<details>
<summary>✅ Solution</summary>

```kql
let baseline_avg = toscalar(
    idoc_raw
    | where timestamp > ago(7d)
    | summarize count() by bin(timestamp, 1h)
    | summarize avg(count_)
);

let last_hour_data = idoc_raw | where timestamp > ago(1h);

let volume_check = 
    last_hour_data
    | summarize Hourly_Count = count()
    | extend Alert = iff(Hourly_Count > baseline_avg * 3, "⚠️ Volume Spike", "✅ Normal")
    | extend Type = "Volume", Value = todouble(Hourly_Count), Threshold = baseline_avg * 3;

let silence_check = 
    last_hour_data
    | summarize Last_Message = max(todatetime(timestamp))
    | extend Minutes_Since = datetime_diff('minute', now(), Last_Message)
    | extend Alert = iff(Minutes_Since > 10, "⚠️ Prolonged Silence", "✅ Normal")
    | extend Type = "Silence", Value = todouble(Minutes_Since), Threshold = 10.0;

let error_rate_check = 
    last_hour_data
    | summarize Total = count(), Errors = countif(control.status != "03")
    | extend Error_Rate = 100.0 * todouble(Errors) / todouble(Total)
    | extend Alert = iff(Error_Rate > 5, "⚠️ High Error Rate", "✅ Normal")
    | extend Type = "Error Rate", Value = Error_Rate, Threshold = 5.0;

let latency_check = 
    last_hour_data
    | extend latency_seconds = datetime_diff('second', ingestion_time(), todatetime(timestamp))
    | summarize P95_Latency = percentile(latency_seconds, 95)
    | extend Alert = iff(P95_Latency > 120, "⚠️ High Latency", "✅ Normal")
    | extend Type = "P95 Latency", Value = todouble(P95_Latency), Threshold = 120.0;

union volume_check, silence_check, error_rate_check, latency_check
| project Type, Alert, Value, Threshold
```
</details>

---

### Challenge 4.3: Business Insights - Order-to-Shipment Time

**Objective:** Calculate average time from order creation to shipment for each SAP system.

**Requirements:**
- Match ORDERS messages with corresponding SHPMNT messages (by document number)
- Calculate time difference
- Group by SAP system
- Show average, P50, P95

**Note:** This is a simplified version. In reality, you'd need proper order-shipment mapping.

<details>
<summary>✅ Solution</summary>

```kql
// Simplified approach: Compare timestamp distributions
let orders = idoc_raw
    | where message_type startswith "ORDERS"
    | summarize Order_Time = avg(todatetime(timestamp)) by sap_system;

let shipments = idoc_raw
    | where message_type startswith "SHPMNT"
    | summarize Shipment_Time = avg(todatetime(timestamp)) by sap_system;

orders
| join kind=inner (shipments) on sap_system
| extend Avg_Order_to_Ship_Hours = datetime_diff('hour', Shipment_Time, Order_Time)
| project sap_system, Avg_Order_to_Ship_Hours
| order by Avg_Order_to_Ship_Hours
```
</details>

---

## 🏆 Bonus Challenge: Create Your Own Function

**Objective:** Create a reusable KQL function that returns a health summary for any time range.

**Requirements:**
- Function should accept `hours_back` parameter
- Return: message count, distinct types, avg latency, error count
- Include a health status (Healthy/Warning/Critical)

<details>
<summary>✅ Solution</summary>

```kql
.create-or-alter function HealthSummary(hours_back: int = 1) {
    let data = idoc_raw | where timestamp > ago(hours_back * 1h);
    
    data
    | summarize 
        Message_Count = count(),
        Distinct_Types = dcount(message_type),
        Avg_Latency_Sec = avg(datetime_diff('second', ingestion_time(), todatetime(timestamp))),
        Error_Count = countif(control.status != "03")
    | extend Error_Rate = 100.0 * todouble(Error_Count) / todouble(Message_Count)
    | extend Health_Status = case(
        Message_Count == 0, "❌ CRITICAL - No Data",
        Error_Rate > 10, "⚠️ WARNING - High Error Rate",
        Avg_Latency_Sec > 120, "⚠️ WARNING - High Latency",
        "✅ HEALTHY"
    )
}

// Usage
HealthSummary(24)
```
</details>

---

## ✅ Completion Checklist

Mark off the exercises you've completed:

### Level 1: Beginner
- [ ] Exercise 1.1: Count by SAP System
- [ ] Exercise 1.2: Last 6 Hours
- [ ] Exercise 1.3: Distinct Count
- [ ] Exercise 1.4: Specific Message Type

### Level 2: Intermediate
- [ ] Exercise 2.1: Hourly Rate
- [ ] Exercise 2.2: Business Hours
- [ ] Exercise 2.3: Growth Trend
- [ ] Exercise 2.4: Peak Hour

### Level 3: Advanced
- [ ] Exercise 3.1: Latency Percentiles
- [ ] Exercise 3.2: Volume Outliers
- [ ] Exercise 3.3: Late Orders
- [ ] Exercise 3.4: Rolling Average
- [ ] Exercise 3.5: Multi-Dimensional Analysis

### Level 4: Expert
- [ ] Challenge 4.1: Data Quality Dashboard
- [ ] Challenge 4.2: Smart Alerting
- [ ] Challenge 4.3: Order-to-Shipment Time

### Bonus
- [ ] Create Custom Health Function

---

## 🎓 Next Steps

Completed all exercises? Great work! Here's what to do next:

1. **Practice with Real Data**: Run these queries on your actual Eventhouse data
2. **Build Dashboards**: Pin your favorite queries to Fabric dashboards
3. **Set Up Alerts**: Use Data Activator to get notified of anomalies
4. **Continue Learning**: Move on to [Module 4 - Lakehouse Architecture](../labs/module4-lakehouse-layers.md)

---

## 💡 Tips for Success

- **Start Small**: Begin with Level 1 even if you have SQL experience
- **Experiment**: Modify queries to see different results
- **Use .show**: Explore functions with `.show functions` and `.show tables`
- **Read Error Messages**: KQL provides helpful error guidance
- **Check Documentation**: [KQL Quick Reference](https://learn.microsoft.com/azure/data-explorer/kusto/query/kql-quick-reference)

---

**Questions or Stuck?** Review the [Module 3 Tutorial](../labs/module3-kql-queries.md) or check the [Workshop README](../README.md) for troubleshooting.

Happy querying! 🚀
