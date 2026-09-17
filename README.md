# AOBO Configuration — Wortell CSP

Assigns Azure RBAC roles to Wortell and Ingram Micro admin groups across all subscriptions in a customer tenant, so Wortell support staff can manage the customer environment without requiring guest invitations or manual access requests.

---

## English

### What you need

- **Owner** or **User Access Administrator** rights on every subscription the script should configure — this is what lets it actually create the role assignments
- An Azure account with **Global Administrator** rights on the tenant — needed for Step 1 below, which grants your account Owner/User Access Administrator at the root management group (covering every subscription) plus access to the Reservations scope
  - Already have Owner/User Access Administrator on the subscriptions directly? You can skip the root-management-group part, but you still need Step 1's elevated access toggle enabled for the Reservations scope to succeed
- Access to the Azure portal

---

### Step 1 — Enable elevated access

> **Why?** The script assigns roles on the Azure Reservations scope, which is not covered by regular administrator permissions. This one-time step grants the necessary access.

1. Go to **[https://portal.azure.com](https://portal.azure.com)** and sign in
2. Search for **Entra ID** and open it
3. Go to **Properties**
4. Under **Access management for Azure resources**, set the toggle to **Yes**
5. Click **Save**

---

### Step 2 — Sign in to the Azure portal

Go to **[https://portal.azure.com](https://portal.azure.com)** and sign in with your administrator account.

> **Using multiple directories?** Click your account name in the top-right corner, select **Switch directory**, and choose the correct tenant before continuing.

---

### Step 3 — Open Cloud Shell

Click the **Cloud Shell button** ( `>_` ) in the top navigation bar.

```text
[Azure portal top bar]  🔍  Portal menu  ...  >_  🔔  ⚙️  👤
                                               ↑
                                         Click here
```

**If this is your first time using Cloud Shell:**
Azure will ask you to select a subscription — pick any and click **Confirm**. Wait a moment for the shell to initialize.

**If the shell opens in Bash mode** (you see a `$` prompt):
Click the dropdown in the top-left of the shell panel and select **PowerShell**. Wait for the `PS >` prompt to appear.

---

### Step 4 — Run the script

Copy the command below, paste it into the Cloud Shell, and press **Enter**.

```powershell
Invoke-Expression (Invoke-WebRequest -Uri "https://raw.githubusercontent.com/PaulSchuurWortell/AOBO-WortellCSP/main/AOBO-WortellCSP.ps1" -UseBasicParsing).Content
```

The script runs automatically. This may take a few minutes — do not close the browser window.

> **What this does:** After a 5-second countdown (press **Ctrl+C** to cancel), the script assigns the Wortell and Ingram Micro support groups access to **every enabled subscription** in this tenant. This is a real, live change — not a preview. Management groups are not touched.

---

### Step 5 — Confirm the result

When the script finishes its summary, it will wait for you to press **Enter** before the prompt returns. This is expected — the script has already completed; it has not frozen.

When the script finishes, you will see a summary ending with one of the following:

```text
✓ SUCCESS: AOBO configuration completed without errors
```

or

```text
⚠ COMPLETED with X error(s) — see details above
```

**Take a screenshot of the full summary and send it to your Wortell contact to confirm completion.**

If you see errors and are unsure how to proceed, contact Wortell before closing the browser.

---

### Step 6 — Disable elevated access

1. Go to **Entra ID → Properties**
2. Set **Access management for Azure resources** back to **No**
3. Click **Save**

---
---

## Nederlands

### Wat je nodig hebt

- De rol **Eigenaar (Owner)** of **Gebruikerstoegangsbeheerder (User Access Administrator)** op elk abonnement dat het script moet configureren — dit is wat het script daadwerkelijk in staat stelt om roltoewijzingen aan te maken
- Een Azure-account met de rol **Globale beheerder (Global Administrator)** op de tenant — nodig voor Stap 1 hieronder, die je account Owner/User Access Administrator geeft op de root management group (dekt alle abonnementen) plus toegang tot het Reservations-bereik
  - Heb je al Owner/User Access Administrator rechtstreeks op de abonnementen? Dan kun je het root-management-group-gedeelte overslaan, maar je hebt de verhoogde toegang uit Stap 1 nog steeds nodig om het Reservations-bereik te laten slagen
- Toegang tot de Azure-portal

---

### Stap 1 — Verhoogde toegang inschakelen

> **Waarom?** Het script wijst rollen toe op het Azure Reservations-bereik, wat niet wordt gedekt door reguliere beheerdersmachtigingen. Deze eenmalige stap verleent de benodigde toegang.

1. Ga naar **[https://portal.azure.com](https://portal.azure.com)** en meld je aan
2. Zoek naar **Entra ID** en open dit
3. Ga naar **Eigenschappen**
4. Zet onder **Toegangsbeheer voor Azure-resources** de schakelaar op **Ja**
5. Klik op **Opslaan**

---

### Stap 2 — Aanmelden bij de Azure-portal

Ga naar **[https://portal.azure.com](https://portal.azure.com)** en meld je aan met je beheerdersaccount.

> **Meerdere mappen?** Klik op je accountnaam rechtsboven, kies **Van map wisselen** en selecteer de juiste tenant voordat je verdergaat.

---

### Stap 3 — Cloud Shell openen

Klik op de **Cloud Shell-knop** ( `>_` ) in de bovenste navigatiebalk.

```text
[Azure portal navigatiebalk]  🔍  Portalmenu  ...  >_  🔔  ⚙️  👤
                                                    ↑
                                              Klik hier
```

**Eerste keer dat je Cloud Shell gebruikt:**
Azure vraagt je een abonnement te selecteren — kies een willekeurig abonnement en klik op **Bevestigen**. Wacht even totdat de shell is geïnitialiseerd.

**Als de shell opent in Bash-modus** (je ziet een `$`-prompt):
Klik op het vervolgkeuzemenu linksboven in het shellvenster en selecteer **PowerShell**. Wacht totdat de prompt verandert naar `PS >`.

---

### Stap 4 — Script uitvoeren

Kopieer de onderstaande opdracht, plak deze in de Cloud Shell en druk op **Enter**.

```powershell
Invoke-Expression (Invoke-WebRequest -Uri "https://raw.githubusercontent.com/PaulSchuurWortell/AOBO-WortellCSP/main/AOBO-WortellCSP.ps1" -UseBasicParsing).Content
```

Het script wordt automatisch uitgevoerd. Dit kan een paar minuten duren — sluit het browservenster niet.

> **Wat dit doet:** Na een aftelling van 5 seconden (druk op **Ctrl+C** om te annuleren) wijst het script de Wortell- en Ingram Micro-supportgroepen toegang toe tot **elk ingeschakeld abonnement** in deze tenant. Dit is een echte, directe wijziging — geen voorbeeldweergave. Management groups worden niet aangepast.

---

### Stap 5 — Resultaat bevestigen

Wanneer het script klaar is met de samenvatting, wacht het tot je op **Enter** drukt voordat de prompt terugkeert. Dit is normaal gedrag — het script is al voltooid en is niet vastgelopen.

Wanneer het script klaar is, zie je een samenvatting die eindigt met:

```text
✓ SUCCESS: AOBO configuration completed without errors
```

of

```text
⚠ COMPLETED with X error(s) — see details above
```

**Maak een screenshot van de volledige samenvatting en stuur deze naar jouw Wortell-contactpersoon ter bevestiging van de uitvoering.**

Zie je foutmeldingen en weet je niet hoe verder? Neem dan contact op met Wortell voordat je het browservenster sluit.

---

### Stap 6 — Verhoogde toegang uitschakelen

1. Ga naar **Entra ID → Eigenschappen**
2. Zet **Toegangsbeheer voor Azure-resources** terug op **Nee**
3. Klik op **Opslaan**
