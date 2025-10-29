#!/usr/bin/env python3
"""
Créer des domaines d'entreprise réalistes pour démos Purview
Avec Glossary Terms et OKRs génériques pour chaque domaine
"""

from azure.identity import DefaultAzureCredential
import requests
import json
import uuid
import time
from datetime import datetime, timedelta

# Configuration
PURVIEW_ACCOUNT = "stpurview"
API_ENDPOINT = f"https://{PURVIEW_ACCOUNT}.purview.azure.com"
API_VERSION = "2025-09-15-preview"

# Définition des domaines d'entreprise
ENTERPRISE_DOMAINS = {
    "Finance": {
        "description": "Financial management, accounting, budgeting, and financial reporting. Responsible for company financial health, compliance, and strategic financial planning.",
        "type": "LineOfBusiness",
        "objectives": [
            {
                "name": "Financial Accuracy & Compliance",
                "definition": "Ensure 100% accuracy in financial reporting and maintain full compliance with regulatory requirements (SOX, IFRS, local GAAP). Reduce audit findings and improve financial controls.",
                "keyResults": [
                    {
                        "name": "Audit Findings",
                        "definition": "Reduce audit findings to zero critical and less than 5 medium findings per quarter",
                        "progress": 3,
                        "goal": 5,
                        "status": "OnTrack"
                    },
                    {
                        "name": "Month-End Close Time",
                        "definition": "Complete month-end close process within 5 business days",
                        "progress": 6,
                        "goal": 5,
                        "status": "Behind"
                    },
                    {
                        "name": "Financial Data Quality",
                        "definition": "Achieve 99.5% data accuracy in financial systems",
                        "progress": 99.2,
                        "goal": 99.5,
                        "status": "OnTrack"
                    }
                ]
            },
            {
                "name": "Cost Optimization",
                "definition": "Optimize operational costs and improve profit margins through data-driven decision making, automated processes, and strategic vendor management.",
                "keyResults": [
                    {
                        "name": "Operating Expense Reduction",
                        "definition": "Reduce operating expenses by 8% year-over-year",
                        "progress": 5.2,
                        "goal": 8.0,
                        "status": "OnTrack"
                    },
                    {
                        "name": "Process Automation",
                        "definition": "Automate 60% of manual financial processes",
                        "progress": 42,
                        "goal": 60,
                        "status": "OnTrack"
                    },
                    {
                        "name": "Budget Variance",
                        "definition": "Maintain budget variance under 3% across all departments",
                        "progress": 4.1,
                        "goal": 3.0,
                        "status": "Behind"
                    }
                ]
            },
            {
                "name": "Financial Planning Excellence",
                "definition": "Improve forecasting accuracy and strategic financial planning to support business growth and investment decisions.",
                "keyResults": [
                    {
                        "name": "Forecast Accuracy",
                        "definition": "Achieve 95% accuracy in quarterly revenue forecasts",
                        "progress": 91,
                        "goal": 95,
                        "status": "OnTrack"
                    },
                    {
                        "name": "Cash Flow Visibility",
                        "definition": "Provide 90-day rolling cash flow forecasts with weekly updates",
                        "progress": 60,
                        "goal": 90,
                        "status": "OnTrack"
                    }
                ]
            }
        ],
        "glossaryTerms": [
            {
                "name": "General Ledger",
                "acronym": "GL",
                "definition": "The complete record of all financial transactions of a company, organized by accounts. The GL is the foundation for financial statements and reporting.",
                "relatedTerms": ["Chart of Accounts", "Journal Entry", "Trial Balance"]
            },
            {
                "name": "Chart of Accounts",
                "acronym": "COA",
                "definition": "A structured listing of all accounts used in the general ledger, organized by account type (assets, liabilities, equity, revenue, expenses).",
                "relatedTerms": ["General Ledger", "Account Code", "Cost Center"]
            },
            {
                "name": "Accounts Payable",
                "acronym": "AP",
                "definition": "Money owed by the company to suppliers and vendors for goods and services purchased on credit. Represents short-term liabilities.",
                "relatedTerms": ["Accounts Receivable", "Invoice", "Payment Terms"]
            },
            {
                "name": "Accounts Receivable",
                "acronym": "AR",
                "definition": "Money owed to the company by customers for goods and services sold on credit. Represents short-term assets.",
                "relatedTerms": ["Accounts Payable", "Invoice", "Days Sales Outstanding"]
            },
            {
                "name": "EBITDA",
                "acronym": "EBITDA",
                "definition": "Earnings Before Interest, Taxes, Depreciation, and Amortization. A measure of company profitability and operational performance.",
                "relatedTerms": ["Operating Income", "Net Income", "Cash Flow"]
            },
            {
                "name": "Working Capital",
                "acronym": "WC",
                "definition": "Current assets minus current liabilities. Measures a company's short-term financial health and operational efficiency.",
                "relatedTerms": ["Current Ratio", "Quick Ratio", "Cash Conversion Cycle"]
            },
            {
                "name": "Cost Center",
                "acronym": "CC",
                "definition": "A department or function within an organization that does not directly generate revenue but incurs costs. Used for budget allocation and cost tracking.",
                "relatedTerms": ["Profit Center", "Budget", "Variance Analysis"]
            },
            {
                "name": "Journal Entry",
                "acronym": "JE",
                "definition": "A record of a business transaction in the accounting system, showing debits and credits to affected accounts.",
                "relatedTerms": ["General Ledger", "Posting", "Adjusting Entry"]
            }
        ]
    },
    
    "Human Resources": {
        "description": "Talent management, employee development, compensation, benefits, and workforce planning. Focused on building a high-performing, engaged, and diverse workforce.",
        "type": "LineOfBusiness",
        "objectives": [
            {
                "name": "Talent Acquisition Excellence",
                "definition": "Attract, hire, and onboard top talent efficiently to support business growth. Reduce time-to-hire and improve candidate quality and experience.",
                "keyResults": [
                    {
                        "name": "Time to Hire",
                        "definition": "Reduce average time to hire to 30 days or less",
                        "progress": 38,
                        "goal": 30,
                        "status": "Behind"
                    },
                    {
                        "name": "Quality of Hire",
                        "definition": "Achieve 90% manager satisfaction with new hire quality",
                        "progress": 85,
                        "goal": 90,
                        "status": "OnTrack"
                    },
                    {
                        "name": "Offer Acceptance Rate",
                        "definition": "Maintain offer acceptance rate at 85% or higher",
                        "progress": 82,
                        "goal": 85,
                        "status": "OnTrack"
                    }
                ]
            },
            {
                "name": "Employee Engagement & Retention",
                "definition": "Increase employee engagement, satisfaction, and retention to reduce turnover costs and maintain organizational knowledge.",
                "keyResults": [
                    {
                        "name": "Employee Engagement Score",
                        "definition": "Achieve employee engagement score of 80% or higher",
                        "progress": 76,
                        "goal": 80,
                        "status": "OnTrack"
                    },
                    {
                        "name": "Voluntary Turnover Rate",
                        "definition": "Reduce voluntary turnover to 10% or below annually",
                        "progress": 12.5,
                        "goal": 10.0,
                        "status": "Behind"
                    },
                    {
                        "name": "Employee Net Promoter Score",
                        "definition": "Achieve eNPS of 40 or higher",
                        "progress": 35,
                        "goal": 40,
                        "status": "OnTrack"
                    }
                ]
            },
            {
                "name": "Learning & Development",
                "definition": "Build a culture of continuous learning and development to enhance employee skills, career growth, and organizational capability.",
                "keyResults": [
                    {
                        "name": "Training Hours per Employee",
                        "definition": "Provide 40+ hours of training per employee annually",
                        "progress": 28,
                        "goal": 40,
                        "status": "OnTrack"
                    },
                    {
                        "name": "Leadership Pipeline",
                        "definition": "Identify and develop 50 high-potential employees for leadership roles",
                        "progress": 32,
                        "goal": 50,
                        "status": "OnTrack"
                    },
                    {
                        "name": "Skills Gap Closure",
                        "definition": "Close 70% of identified critical skills gaps through training programs",
                        "progress": 45,
                        "goal": 70,
                        "status": "Behind"
                    }
                ]
            }
        ],
        "glossaryTerms": [
            {
                "name": "Full-Time Equivalent",
                "acronym": "FTE",
                "definition": "A unit that indicates the workload of an employed person in a way that makes workloads comparable across contexts. 1.0 FTE = full-time employment.",
                "relatedTerms": ["Headcount", "Part-Time", "Contractor"]
            },
            {
                "name": "Employee Net Promoter Score",
                "acronym": "eNPS",
                "definition": "A metric used to measure employee loyalty and engagement by asking how likely employees are to recommend the company as a place to work.",
                "relatedTerms": ["Employee Engagement", "Employee Satisfaction", "Retention"]
            },
            {
                "name": "Time to Hire",
                "acronym": "TTH",
                "definition": "The number of days between when a candidate applies and when they accept the job offer. Measures recruitment efficiency.",
                "relatedTerms": ["Time to Fill", "Recruitment Cycle", "Hiring Velocity"]
            },
            {
                "name": "Attrition Rate",
                "acronym": "AR",
                "definition": "The rate at which employees leave the organization over a specific period, including voluntary and involuntary departures.",
                "relatedTerms": ["Turnover Rate", "Retention Rate", "Voluntary Turnover"]
            },
            {
                "name": "Performance Review",
                "acronym": "PR",
                "definition": "A formal assessment of an employee's job performance, typically conducted annually or semi-annually, used for feedback, development, and compensation decisions.",
                "relatedTerms": ["Performance Management", "360 Feedback", "Goal Setting"]
            },
            {
                "name": "Onboarding",
                "acronym": None,
                "definition": "The process of integrating new employees into the organization, including orientation, training, and socialization to help them become productive quickly.",
                "relatedTerms": ["Orientation", "New Hire", "Employee Experience"]
            },
            {
                "name": "Succession Planning",
                "acronym": "SP",
                "definition": "The process of identifying and developing employees to fill key leadership and critical positions in the future.",
                "relatedTerms": ["Talent Pipeline", "Leadership Development", "High Potential"]
            },
            {
                "name": "Total Compensation",
                "acronym": "TC",
                "definition": "The complete package of salary, bonuses, benefits, equity, and other rewards provided to employees.",
                "relatedTerms": ["Base Salary", "Variable Pay", "Benefits", "Equity Compensation"]
            },
            {
                "name": "Diversity & Inclusion",
                "acronym": "D&I",
                "definition": "Organizational initiatives and practices to create a diverse workforce and inclusive culture where all employees feel valued and can contribute fully.",
                "relatedTerms": ["Equal Opportunity", "Belonging", "Workforce Diversity"]
            }
        ]
    },
    
    "Sales & Marketing": {
        "description": "Revenue generation, customer acquisition, brand management, and market development. Drives business growth through effective sales strategies and marketing campaigns.",
        "type": "LineOfBusiness",
        "objectives": [
            {
                "name": "Revenue Growth",
                "definition": "Achieve aggressive revenue growth targets through new customer acquisition, upselling, and market expansion.",
                "keyResults": [
                    {
                        "name": "Annual Recurring Revenue",
                        "definition": "Grow ARR by 25% year-over-year",
                        "progress": 18,
                        "goal": 25,
                        "status": "OnTrack"
                    },
                    {
                        "name": "New Customer Acquisition",
                        "definition": "Acquire 500 new customers this year",
                        "progress": 320,
                        "goal": 500,
                        "status": "OnTrack"
                    },
                    {
                        "name": "Average Deal Size",
                        "definition": "Increase average deal size to $50K or higher",
                        "progress": 42000,
                        "goal": 50000,
                        "status": "OnTrack"
                    }
                ]
            },
            {
                "name": "Sales Efficiency",
                "definition": "Optimize sales processes, improve conversion rates, and reduce sales cycle time to maximize productivity and win rates.",
                "keyResults": [
                    {
                        "name": "Sales Cycle Length",
                        "definition": "Reduce average sales cycle to 60 days or less",
                        "progress": 75,
                        "goal": 60,
                        "status": "Behind"
                    },
                    {
                        "name": "Win Rate",
                        "definition": "Achieve 30% win rate on qualified opportunities",
                        "progress": 26,
                        "goal": 30,
                        "status": "OnTrack"
                    },
                    {
                        "name": "Sales Quota Attainment",
                        "definition": "Achieve 80% of sales reps at or above quota",
                        "progress": 68,
                        "goal": 80,
                        "status": "Behind"
                    }
                ]
            },
            {
                "name": "Marketing ROI & Lead Quality",
                "definition": "Maximize marketing return on investment and generate high-quality leads that convert to revenue.",
                "keyResults": [
                    {
                        "name": "Marketing Qualified Leads",
                        "definition": "Generate 2000 marketing qualified leads per quarter",
                        "progress": 1650,
                        "goal": 2000,
                        "status": "OnTrack"
                    },
                    {
                        "name": "Lead to Opportunity Conversion",
                        "definition": "Achieve 25% conversion rate from MQL to sales opportunity",
                        "progress": 22,
                        "goal": 25,
                        "status": "OnTrack"
                    },
                    {
                        "name": "Marketing ROI",
                        "definition": "Achieve 5:1 marketing ROI (revenue generated per marketing dollar spent)",
                        "progress": 4.2,
                        "goal": 5.0,
                        "status": "OnTrack"
                    }
                ]
            }
        ],
        "glossaryTerms": [
            {
                "name": "Customer Acquisition Cost",
                "acronym": "CAC",
                "definition": "The total cost of acquiring a new customer, including all sales and marketing expenses divided by the number of new customers acquired.",
                "relatedTerms": ["Customer Lifetime Value", "Marketing ROI", "Sales Efficiency"]
            },
            {
                "name": "Customer Lifetime Value",
                "acronym": "CLV/LTV",
                "definition": "The predicted total revenue a company expects to earn from a customer over the entire business relationship.",
                "relatedTerms": ["Customer Acquisition Cost", "Retention Rate", "Churn Rate"]
            },
            {
                "name": "Marketing Qualified Lead",
                "acronym": "MQL",
                "definition": "A lead that has been deemed more likely to become a customer based on marketing engagement and lead scoring criteria.",
                "relatedTerms": ["Sales Qualified Lead", "Lead Scoring", "Conversion Rate"]
            },
            {
                "name": "Sales Qualified Lead",
                "acronym": "SQL",
                "definition": "A prospective customer that has been qualified by the sales team as ready for direct sales engagement.",
                "relatedTerms": ["Marketing Qualified Lead", "Opportunity", "Pipeline"]
            },
            {
                "name": "Conversion Rate",
                "acronym": "CR",
                "definition": "The percentage of prospects who take a desired action (e.g., MQL to SQL, SQL to Opportunity, Opportunity to Close).",
                "relatedTerms": ["Funnel", "Win Rate", "Sales Velocity"]
            },
            {
                "name": "Annual Recurring Revenue",
                "acronym": "ARR",
                "definition": "The value of recurring revenue normalized to a one-year period. Key metric for subscription-based businesses.",
                "relatedTerms": ["Monthly Recurring Revenue", "Revenue Growth", "Churn"]
            },
            {
                "name": "Customer Churn Rate",
                "acronym": "Churn",
                "definition": "The percentage of customers who stop doing business with a company during a specific time period.",
                "relatedTerms": ["Retention Rate", "Customer Lifetime Value", "Net Revenue Retention"]
            },
            {
                "name": "Sales Pipeline",
                "acronym": None,
                "definition": "The visual representation of where prospects are in the sales process, from initial contact to closed deal.",
                "relatedTerms": ["Opportunity", "Sales Stage", "Forecast"]
            },
            {
                "name": "Net Promoter Score",
                "acronym": "NPS",
                "definition": "A customer loyalty metric measuring how likely customers are to recommend a company's products or services to others.",
                "relatedTerms": ["Customer Satisfaction", "Customer Loyalty", "Advocacy"]
            },
            {
                "name": "Return on Ad Spend",
                "acronym": "ROAS",
                "definition": "Revenue generated for every dollar spent on advertising. Calculated as revenue from ads divided by cost of ads.",
                "relatedTerms": ["Marketing ROI", "Cost Per Acquisition", "Ad Performance"]
            }
        ]
    }
}

def create_domain(credential, domain_name, domain_data):
    """Créer un domaine"""
    token = credential.get_token("https://purview.azure.net/.default")
    
    headers = {
        "Authorization": f"Bearer {token.token}",
        "Content-Type": "application/json"
    }
    
    domain_payload = {
        "id": str(uuid.uuid4()),
        "name": domain_name,
        "description": domain_data["description"],
        "type": domain_data["type"],
        "status": "PUBLISHED",
        "isRestricted": False,
        "thumbnail": {
            "color": "#0078D4"
        }
    }
    
    url = f"{API_ENDPOINT}/datagovernance/catalog/businessdomains?api-version={API_VERSION}"
    
    try:
        response = requests.post(url, headers=headers, json=domain_payload)
        
        if response.status_code == 201:
            result = response.json()
            print(f"✅ Domain créé: {domain_name}")
            print(f"   ID: {result.get('id')}")
            return result
        else:
            print(f"❌ Erreur création domain {domain_name}: {response.status_code}")
            print(f"   {response.text[:200]}")
            return None
    except Exception as e:
        print(f"❌ Exception: {str(e)}")
        return None

def create_objective(credential, domain_id, domain_name, obj_data):
    """Créer un Objective pour un domaine"""
    token = credential.get_token("https://purview.azure.net/.default")
    
    headers = {
        "Authorization": f"Bearer {token.token}",
        "Content-Type": "application/json"
    }
    
    target_date = (datetime.now() + timedelta(days=180)).isoformat() + "Z"
    
    objective_payload = {
        "id": str(uuid.uuid4()),
        "definition": obj_data["definition"],
        "domain": domain_id,
        "status": "Published",
        "targetDate": target_date
    }
    
    url = f"{API_ENDPOINT}/datagovernance/catalog/objectives?api-version={API_VERSION}"
    
    try:
        response = requests.post(url, headers=headers, json=objective_payload)
        
        if response.status_code == 201:
            result = response.json()
            print(f"   ✅ Objective: {obj_data['name']}")
            return result
        else:
            print(f"   ❌ Erreur Objective: {obj_data['name']}")
            return None
    except Exception as e:
        print(f"   ❌ Exception: {str(e)}")
        return None

def create_key_result(credential, objective_id, domain_id, kr_data):
    """Créer un Key Result"""
    token = credential.get_token("https://purview.azure.net/.default")
    
    headers = {
        "Authorization": f"Bearer {token.token}",
        "Content-Type": "application/json"
    }
    
    kr_payload = {
        "id": str(uuid.uuid4()),
        "domainId": domain_id,
        "definition": kr_data["definition"],
        "progress": kr_data["progress"],
        "goal": kr_data["goal"],
        "max": kr_data.get("max", kr_data["goal"]),
        "status": kr_data["status"]
    }
    
    url = f"{API_ENDPOINT}/datagovernance/catalog/objectives/{objective_id}/keyResults?api-version={API_VERSION}"
    
    try:
        response = requests.post(url, headers=headers, json=kr_payload)
        
        if response.status_code == 201:
            return response.json()
        else:
            return None
    except Exception as e:
        return None

def create_glossary_term(credential, domain_id, domain_name, term_data):
    """Créer un Glossary Term"""
    token = credential.get_token("https://purview.azure.net/.default")
    
    headers = {
        "Authorization": f"Bearer {token.token}",
        "Content-Type": "application/json"
    }
    
    term_payload = {
        "id": str(uuid.uuid4()),
        "name": term_data["name"],
        "domain": domain_id,
        "definition": term_data["definition"],
        "status": "Published"
    }
    
    if term_data.get("acronym"):
        term_payload["acronym"] = term_data["acronym"]
    
    url = f"{API_ENDPOINT}/datagovernance/catalog/terms?api-version={API_VERSION}"
    
    try:
        response = requests.post(url, headers=headers, json=term_payload)
        
        if response.status_code == 201:
            result = response.json()
            acronym_str = f" ({term_data['acronym']})" if term_data.get('acronym') else ""
            print(f"      ✅ {term_data['name']}{acronym_str}")
            return result
        else:
            return None
    except Exception as e:
        return None

def main():
    print("\n" + "=" * 80)
    print("  CRÉATION DOMAINES D'ENTREPRISE POUR DÉMO PURVIEW")
    print("=" * 80)
    
    credential = DefaultAzureCredential()
    
    all_results = {
        "domains": [],
        "objectives": [],
        "keyResults": [],
        "glossaryTerms": [],
        "createdAt": datetime.now().isoformat()
    }
    
    for domain_name, domain_data in ENTERPRISE_DOMAINS.items():
        print(f"\n{'='*80}")
        print(f"  DOMAINE: {domain_name}")
        print(f"{'='*80}")
        
        # Créer le domaine
        domain = create_domain(credential, domain_name, domain_data)
        if not domain:
            continue
        
        domain_id = domain.get("id")
        all_results["domains"].append(domain)
        time.sleep(1)
        
        # Créer les Objectives
        print(f"\n  🎯 Objectives ({len(domain_data['objectives'])}):")
        for obj_data in domain_data["objectives"]:
            objective = create_objective(credential, domain_id, domain_name, obj_data)
            if objective:
                all_results["objectives"].append(objective)
                objective_id = objective.get("id")
                
                # Créer les Key Results
                kr_count = 0
                for kr_data in obj_data["keyResults"]:
                    kr = create_key_result(credential, objective_id, domain_id, kr_data)
                    if kr:
                        all_results["keyResults"].append(kr)
                        kr_count += 1
                    time.sleep(0.3)
                
                print(f"      → {kr_count} Key Results créés")
            time.sleep(0.5)
        
        # Créer les Glossary Terms
        print(f"\n  📚 Glossary Terms ({len(domain_data['glossaryTerms'])}):")
        for term_data in domain_data["glossaryTerms"]:
            term = create_glossary_term(credential, domain_id, domain_name, term_data)
            if term:
                all_results["glossaryTerms"].append(term)
            time.sleep(0.3)
        
        time.sleep(1)
    
    # Sauvegarder les résultats
    with open("demo_domains_created.json", "w") as f:
        json.dump(all_results, f, indent=2)
    
    # Résumé final
    print("\n" + "=" * 80)
    print("  RÉSUMÉ CRÉATION")
    print("=" * 80)
    print(f"\n✅ Domaines créés: {len(all_results['domains'])}")
    print(f"✅ Objectives créés: {len(all_results['objectives'])}")
    print(f"✅ Key Results créés: {len(all_results['keyResults'])}")
    print(f"✅ Glossary Terms créés: {len(all_results['glossaryTerms'])}")
    
    print(f"\n💾 Résultats sauvegardés: demo_domains_created.json")
    
    print("\n" + "=" * 80)
    print("  DOMAINES CRÉÉS")
    print("=" * 80)
    for domain in all_results["domains"]:
        print(f"\n📦 {domain.get('name')}")
        print(f"   ID: {domain.get('id')}")
        print(f"   Type: {domain.get('domainType')}")
    
    print("\n🌐 Visualiser dans Purview Portal:")
    print(f"   https://web.purview.azure.com/resource/{PURVIEW_ACCOUNT}")
    
    print("\n" + "=" * 80)
    print("\n✨ Environnement démo créé avec succès !\n")

if __name__ == "__main__":
    main()
