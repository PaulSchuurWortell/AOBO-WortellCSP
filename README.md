# AOBO Configuration — Wortell CSP

Assigns Azure RBAC roles to Wortell and Ingram Micro admin groups across all management groups and subscriptions in a customer tenant, so Wortell support staff can manage the customer environment without requiring guest invitations or manual access requests.

---

## English

### What you need

- An Azure account with **Global Administrator** rights on the tenant
- Access to the Azure portal

---

### Step 1 — Sign in to the Azure portal

Go to **[https://portal.azure.com](https://portal.azure.com)** and sign in with your administrator account.

> **Using multiple directories?** Click your account name in the top-right corner, select **Switch directory**, and choose the correct tenant before continuing.

---

### Step 2 — Open Cloud Shell

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

### Step 3 — Run the script

Copy the command below, paste it into the Cloud Shell, and press **Enter**.

```powershell
Invoke-Expression (Invoke-WebRequest -Uri "https://raw.githubusercontent.com/PaulSchuurWortell/AOBO-WortellCSP/main/AOBO-WortellCSP.ps1" -UseBasicParsing).Content
```

The script runs automatically. This may take a few minutes — do not close the browser window.

---

### Step 4 — Confirm the result

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
---

## Nederlands

### Wat je nodig hebt

- Een Azure-account met de rol **Globale beheerder (Global Administrator)** op de tenant
- Toegang tot de Azure-portal

---

### Stap 1 — Aanmelden bij de Azure-portal

Ga naar **[https://portal.azure.com](https://portal.azure.com)** en meld je aan met je beheerdersaccount.

> **Meerdere mappen?** Klik op je accountnaam rechtsboven, kies **Van map wisselen** en selecteer de juiste tenant voordat je verdergaat.

---

### Stap 2 — Cloud Shell openen

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

### Stap 3 — Script uitvoeren

Kopieer de onderstaande opdracht, plak deze in de Cloud Shell en druk op **Enter**.

```powershell
Invoke-Expression (Invoke-WebRequest -Uri "https://raw.githubusercontent.com/PaulSchuurWortell/AOBO-WortellCSP/main/AOBO-WortellCSP.ps1" -UseBasicParsing).Content
```

Het script wordt automatisch uitgevoerd. Dit kan een paar minuten duren — sluit het browservenster niet.

---

### Stap 4 — Resultaat bevestigen

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
