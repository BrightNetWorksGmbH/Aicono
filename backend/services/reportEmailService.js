const Mailjet = require("node-mailjet");

// Mailjet configuration
const MAILJET_API_KEY = process.env.MJ_API_KEY;
const MAILJET_SECRET_KEY = process.env.MJ_SECRET_KEY;
const FROM_EMAIL = process.env.MJ_FROM_EMAIL;
const FROM_NAME = process.env.FROM_NAME || "AICONO EMS";
const FRONTEND_URL = process.env.FRONTEND_URL || "http://localhost:3000";

// Initialize Mailjet client
const mailjet = new Mailjet({
  apiKey: MAILJET_API_KEY,
  apiSecret: MAILJET_SECRET_KEY,
});

/**
 * Build custom report email template
 * @param {Object} params - Template parameters
 * @returns {String} HTML content
 */
function buildReportEmailTemplate({
  recipientName,
  statusText,
  progressBarPercent,
  totalEnergy,
  energyUnit,
  averagePower,
  powerUnit,
  peakPower,
  buildingName,
  viewReportUrl,
  unsubscribeUrl,
  reportConfigName
}) {
  // Progress bar HTML (static data for now - 25-30% for unkritisch)
  const progressBarFill = progressBarPercent || 28;
  const progressBarHtml = `
    <div style="width: 100%; background-color: rgba(255, 255, 255, 0.3); height: 8px; border-radius: 4px; margin-top: 10px; overflow: hidden;">
      <div style="width: ${progressBarFill}%; background-color: #90EE90; height: 100%; transition: width 0.3s ease;"></div>
    </div>
  `;

  return `
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>${reportConfigName || 'Daily Report'} - BRIGHT NETWORKS</title>
      <style>
        body { 
          font-family: Arial, sans-serif; 
          line-height: 1.6; 
          color: #333; 
          margin: 0; 
          padding: 20px; 
          background-color: #f4f4f4; 
        }
        .email-container { 
          max-width: 600px; 
          margin: 0 auto; 
          background: #ffffff; 
          border-radius: 8px; 
          overflow: hidden; 
          box-shadow: 0 2px 4px rgba(0,0,0,0.1); 
        }
        .header-section { 
          background: linear-gradient(135deg, #2596be 0%, #30b3e2 100%); 
          padding: 20px; 
          border-radius: 16px; 
          color: white; 
          text-align: center; 
          margin-bottom: 20px; 
        }
        .header-greeting { 
          color: white; 
          margin: 0 0 20px 0; 
          font-size: 24px; 
          font-weight: normal; 
          line-height: 1.4; 
        }
        .status-section { 
          display: flex; 
          align-items: center; 
          justify-content: center; 
          gap: 10px; 
          margin-bottom: 10px; 
        }
        .status-text { 
          color: white; 
          font-size: 14px; 
        }
        .header-button { 
          display: inline-block; 
          border: 5px solid white !important; 
          border-radius: 0 !important; 
          background: transparent; 
          color: white !important; 
          font-weight: bold; 
          padding: 12px 24px; 
          text-decoration: none !important; 
          margin-top: 20px; 
          font-size: 16px; 
        }
        .header-button:hover { 
          background: rgba(255, 255, 255, 0.1); 
        }
        .content-section { 
          padding: 0 20px 20px; 
        }
        .key-facts { 
          background: #f0f9ff; 
          border-left: 4px solid #2596be; 
          padding: 15px; 
          margin: 20px 0; 
          border-radius: 4px; 
        }
        .key-facts h3 { 
          color: #2596be; 
          margin-top: 0; 
          margin-bottom: 10px; 
        }
        .key-facts table { 
          width: 100%; 
          border-collapse: collapse; 
        }
        .key-facts td { 
          padding: 8px; 
          border-bottom: 1px solid #ddd; 
        }
        .key-facts tr:last-child td { 
          border-bottom: none; 
        }
        .content-button { 
          display: inline-block; 
          border: 5px solid #2596be !important; 
          border-radius: 0 !important; 
          background: transparent; 
          color: #2596be !important; 
          font-weight: bold; 
          padding: 12px 24px; 
          text-decoration: none !important; 
          margin: 20px 0; 
          font-size: 16px; 
          text-align: center; 
        }
        .content-button:hover { 
          background: rgba(37, 150, 190, 0.1); 
        }
        .button-container { 
          text-align: center; 
          margin: 20px 0; 
        }
        .link-fallback { 
          word-break: break-all; 
          background: #f8f9fa; 
          padding: 10px; 
          border-radius: 4px; 
          font-family: monospace; 
          font-size: 12px; 
          margin-top: 10px; 
          color: #2596be; 
        }
        .footer-section { 
          background: #f8f9fa; 
          padding: 20px; 
          text-align: center; 
          color: #666; 
          font-size: 12px; 
          border-top: 1px solid #eee; 
        }
        .footer-section p { 
          margin: 5px 0; 
        }
        a { 
          color: #2596be; 
          text-decoration: none; 
        }
        a:hover { 
          text-decoration: underline; 
        }
        p { 
          margin: 15px 0; 
        }
      </style>
    </head>
    <body>
      <div class="email-container">
        <div class="content-section">
          <!-- Header Section -->
          <div class="header-section">
            <h2 class="header-greeting">Guten Morgen,<br>lieber ${recipientName}, Dein<br>tägliches Reporting<br>steht bereit</h2>
            <div class="status-section">
              <span class="status-text">${statusText}</span>
            </div>
            ${progressBarHtml}
            <div style="margin-top: 20px;">
              <a href="${viewReportUrl}" class="header-button">Jetzt sofort ansehen</a>
            </div>
          </div>

          <!-- Key Facts Section -->
          <div class="key-facts">
            <h3>Key Facts</h3>
            <table>
              <tr>
                <td><strong>Total Energy:</strong></td>
                <td style="text-align: right;">${totalEnergy.toFixed(3)} ${energyUnit}</td>
              </tr>
              <tr>
                <td><strong>Average Power:</strong></td>
                <td style="text-align: right;">${averagePower > 0 ? averagePower.toFixed(3) : 'N/A'} ${averagePower > 0 ? powerUnit : ''}</td>
              </tr>
              <tr>
                <td><strong>Peak Power:</strong></td>
                <td style="text-align: right;">${peakPower.toFixed(3)} ${powerUnit}</td>
              </tr>
            </table>
          </div>

          <!-- Content Text Before Button -->
          <p>Lieber ${recipientName},</p>
          <p>anbei findest Du Dein tägliches Ressourcen-Reporting zur Liegenschaft „${buildingName}".</p>
          <p>Du kannst Dich über den folgenden Link bequem – ohne Eingabe weiterer Identifikationsmerkmale – anmelden. Bitte beachte, dass der Link nicht weitergegeben werden kann und nur funktioniert, wenn er direkt aus dieser E-Mail heraus geöffnet wird.</p>

          <!-- Outside Button -->
          <div class="button-container">
            <a href="${viewReportUrl}" class="content-button">Jetzt sofort ansehen</a>
          </div>

          <!-- Post-Button Text -->
          <p>If the button doesn't work, copy and paste this link into your browser:</p>
          <div class="link-fallback">${viewReportUrl}</div>
          <p>Zusätzlich liegt das Reporting als PDF-Variante im Anhang bei.</p>
          <p>Diese Nachricht erhältst Du on behalf of ${recipientName}, CEO BrightNetWorks GmbH und Mandant von BrightNetWorks.BryteSwitch.de.</p>
          <p>
            Wenn Du künftig kein automatisches Reporting mehr erhalten möchtest, kannst Du es über folgenden Link abbestellen: 
            <a href="${unsubscribeUrl}">👉 Reporting abbestellen</a>
          </p>
          <p>Bei Rückfragen wende Dich bitte an ${recipientName} oder das Administratoren-Team.</p>
          <p style="margin-top: 20px;">Mit besten Grüßen<br>Dein ${recipientName}<br>BrightNetWorks GmbH</p>
        </div>

        <!-- Footer Section -->
        <div class="footer-section">
          <p>Durch das Öffnen dieses Dokuments bestätigst Du gemäß § 126 BGB, dass Du die autorisierte Empfängerperson bist und diese elektronische Übermittlung als rechtsverbindlich anerkennst. Die Weitergabe oder Vervielfältigung des Inhalts ist ohne ausdrückliche Zustimmung der BrightNetWorks GmbH untersagt.</p>
          <p>brightnetworks.switchboard.com</p>
        </div>
      </div>
    </body>
    </html>
  `;
}

/**
 * Report Email Service
 * 
 * Formats and sends scheduled reports via email
 */
class ReportEmailService {
  /**
   * Send scheduled report email
   * @param {Object} recipient - ReportingRecipient object
   * @param {Object} building - Building object
   * @param {Object} reportData - Generated report data
   * @param {Object} reportConfig - Reporting configuration
   * @param {String} token - JWT token for report viewing (optional, if not provided will be generated)
   * @returns {Promise<Object>} Result object with success status
   */
  async sendScheduledReport(recipient, building, reportData, reportConfig, token = null) {
    try {
      if (!recipient || !recipient.email) {
        throw new Error('Recipient email is required');
      }

      // Build report viewing URL with token
      const viewReportUrl = token 
        ? `${FRONTEND_URL}/view-report?token=${encodeURIComponent(token)}`
        : `${FRONTEND_URL}/reports`;

      // Format report as HTML and text (summary only)
      const htmlContent = this.formatReportAsHTML(reportData, reportConfig, building, viewReportUrl, recipient);
      const textContent = this.formatReportAsText(reportData, reportConfig, building, viewReportUrl, recipient);

      // Send email
      const subject = `${reportConfig.name} - ${building.name}`;
      
      const request = mailjet.post("send", { version: "v3.1" }).request({
        Messages: [
          {
            From: {
              Email: FROM_EMAIL,
              Name: FROM_NAME,
            },
            To: [
              {
                Email: recipient.email,
                Name: recipient.name || recipient.email.split("@")[0],
              },
            ],
            Subject: subject,
            TextPart: textContent,
            HTMLPart: htmlContent,
          },
        ],
      });

      const result = await request;

      return {
        ok: true,
        messageId: result.body.Messages[0].To[0].MessageID,
        status: result.body.Messages[0].Status,
      };
    } catch (error) {
      console.error(`[REPORT-EMAIL] Error sending report to ${recipient?.email}:`, error.message);
      return {
        ok: false,
        error: error.message,
      };
    }
  }

  /**
   * Format report as HTML (summary only with "View now" button)
   * @param {Object} reportData - Generated report data
   * @param {Object} reportConfig - Reporting configuration
   * @param {Object} building - Building object
   * @param {String} viewReportUrl - URL to view full report
   * @param {Object} recipient - Recipient object
   * @returns {String} HTML content
   */
  formatReportAsHTML(reportData, reportConfig, building, viewReportUrl, recipient = null) {
    const { timeRange, kpis } = reportData;

    // Format time range
    const timeRangeStr = this.formatTimeRange(timeRange);

    // Determine status (simplified - can be enhanced based on KPIs)
    const dataQuality = kpis.average_quality || 100;
    const hasAnomalies = kpis.data_quality_warning || false;
    const status = hasAnomalies ? 'uncritical' : 'no issues'; // Can be enhanced with more logic
    const statusText = hasAnomalies ? 'Kurzstatus: unkritisch' : 'Kurzstatus: keine Probleme';

    // Get key metrics for summary
    const energyUnit = kpis.energyUnit || 'kWh';
    const powerUnit = kpis.powerUnit || 'kW';
    const totalEnergy = kpis.total_consumption || 0;
    const averagePower = kpis.averagePower || 0;
    const peakPower = kpis.peak || 0;

    // Recipient name for greeting
    const recipientName = recipient?.name || recipient?.email?.split('@')[0] || 'User';

    // Progress bar percentage (static data for now - 25-30% for unkritisch)
    const progressBarPercent = hasAnomalies ? 28 : 30;

    // Unsubscribe URL
    const unsubscribeUrl = `${FRONTEND_URL}/unsubscribe?email=${encodeURIComponent(recipient?.email || '')}`;

    // Build custom email template
    const htmlContent = buildReportEmailTemplate({
      recipientName,
      statusText,
      progressBarPercent,
      totalEnergy,
      energyUnit,
      averagePower,
      powerUnit,
      peakPower,
      buildingName: building.name,
      viewReportUrl,
      unsubscribeUrl,
      reportConfigName: reportConfig.name
    });

    return htmlContent;
  }

  /**
   * Format report as plain text (summary only)
   * @param {Object} reportData - Generated report data
   * @param {Object} reportConfig - Reporting configuration
   * @param {Object} building - Building object
   * @param {String} viewReportUrl - URL to view full report
   * @returns {String} Plain text content
   */
  formatReportAsText(reportData, reportConfig, building, viewReportUrl, recipient = null) {
    const { timeRange, kpis } = reportData;

    const timeRangeStr = this.formatTimeRange(timeRange);
    const recipientName = recipient?.name || recipient?.email?.split('@')[0] || 'User';

    let text = `BRIGHT NETWORKS - ${reportConfig.name}\n\n`;
    text += `Guten Morgen, lieber ${recipientName}, Dein tägliches Reporting steht bereit.\n\n`;
    text += `Kurzstatus: keine Probleme\n\n`;
    text += `${'='.repeat(50)}\n\n`;

    // Summary
    text += `KEY FACTS\n`;
    const energyUnit = kpis.energyUnit || 'kWh';
    const powerUnit = kpis.powerUnit || 'kW';
    const averagePower = kpis.averagePower || 0;
    text += `Total Energy: ${(kpis.total_consumption || 0).toFixed(3)} ${energyUnit}\n`;
    text += `Average Power: ${averagePower > 0 ? averagePower.toFixed(3) : 'N/A'} ${averagePower > 0 ? powerUnit : ''}\n`;
    text += `Peak Power: ${(kpis.peak || 0).toFixed(3)} ${powerUnit}\n\n`;

    text += `Lieber ${recipientName},\n\n`;
    text += `anbei findest Du Dein tägliches Ressourcen-Reporting zur Liegenschaft „${building.name}".\n\n`;
    text += `Du kannst Dich über den folgenden Link bequem – ohne Eingabe weiterer Identifikationsmerkmale – anmelden:\n`;
    text += `${viewReportUrl}\n\n`;
    text += `Bitte beachte, dass der Link nicht weitergegeben werden kann und nur funktioniert, wenn er direkt aus dieser E-Mail heraus geöffnet wird.\n\n`;
    text += `Zusätzlich liegt das Reporting als PDF-Variante im Anhang bei.\n\n`;
    text += `Diese Nachricht erhältst Du on behalf of ${recipientName}, CEO BrightNetWorks GmbH und Mandant von BrightNetWorks.BryteSwitch.de.\n\n`;
    text += `Wenn Du künftig kein automatisches Reporting mehr erhalten möchtest, kannst Du es über folgenden Link abbestellen:\n`;
    text += `${FRONTEND_URL}/unsubscribe?email=${encodeURIComponent(recipient?.email || '')}\n\n`;
    text += `Bei Rückfragen wende Dich bitte an ${recipientName} oder das Administratoren-Team.\n\n`;
    text += `Mit besten Grüßen\nDein ${recipientName}\nBrightNetWorks GmbH\n\n`;
    text += `${'='.repeat(50)}\n`;
    text += `Durch das Öffnen dieses Dokuments bestätigst Du gemäß § 126 BGB, dass Du die autorisierte Empfängerperson bist und diese elektronische Übermittlung als rechtsverbindlich anerkennst.\n`;
    text += `brightnetworks.switchboard.com\n`;

    return text;
  }

  /**
   * Format time range string
   */
  formatTimeRange(timeRange) {
    const start = new Date(timeRange.start).toLocaleDateString();
    const end = new Date(timeRange.end).toLocaleDateString();
    return `${start} to ${end}`;
  }

  /**
   * Format summary section
   * Shows key metrics with proper units and clear labels
   */
  formatSummarySection(reportData, building) {
    const { kpis } = reportData;
    const energyUnit = kpis.energyUnit || 'kWh';
    const powerUnit = kpis.powerUnit || 'kW';
    const totalEnergy = kpis.total_consumption || 0;
    const averageEnergy = kpis.averageEnergy || kpis.average || 0;
    const averagePower = kpis.averagePower || 0;
    const peakPower = kpis.peak || 0;
    
    return `
      <div class="info-box">
        <h3 style="color: #214A59; margin-top: 0;">Summary</h3>
        <table style="width: 100%; border-collapse: collapse;">
          <tr>
            <td style="padding: 8px; border-bottom: 1px solid #eee;"><strong>Total Energy:</strong></td>
            <td style="padding: 8px; border-bottom: 1px solid #eee;">${totalEnergy.toFixed(3)} ${energyUnit}</td>
          </tr>
          <tr>
            <td style="padding: 8px; border-bottom: 1px solid #eee;"><strong>Average Power:</strong></td>
            <td style="padding: 8px; border-bottom: 1px solid #eee;">${averagePower > 0 ? averagePower.toFixed(3) : averageEnergy.toFixed(3)} ${averagePower > 0 ? powerUnit : energyUnit}</td>
          </tr>
          <tr>
            <td style="padding: 8px; border-bottom: 1px solid #eee;"><strong>Peak Power:</strong></td>
            <td style="padding: 8px; border-bottom: 1px solid #eee;">${peakPower.toFixed(3)} ${powerUnit}</td>
          </tr>
          <tr>
            <td style="padding: 8px;"><strong>Data Quality:</strong></td>
            <td style="padding: 8px;">${kpis.average_quality || 100}% ${kpis.data_quality_warning ? '⚠️' : '✓'}</td>
          </tr>
        </table>
      </div>
    `;
  }

  /**
   * Format content section HTML
   */
  formatContentSection(contentType, content) {
    switch (contentType) {
      case 'TotalConsumption': {
        // Use explicit units for clarity
        const totalEnergy = content.totalConsumption || 0;
        const totalEnergyUnit = content.totalConsumptionUnit || content.energyUnit || 'kWh';
        const avgEnergy = content.averageEnergy || content.average || 0;
        const avgEnergyUnit = content.averageEnergyUnit || content.energyUnit || 'kWh';
        const avgPower = content.averagePower || 0;
        const avgPowerUnit = content.averagePowerUnit || content.powerUnit || 'kW';
        const peakPower = content.peak || 0;
        const peakPowerUnit = content.peakUnit || content.powerUnit || 'kW';
        
        return `
          <div class="info-box">
            <h3 style="color: #214A59; margin-top: 0;">Energy & Power Overview</h3>
            <table style="width: 100%; border-collapse: collapse;">
              <tr>
                <td style="padding: 8px; border-bottom: 1px solid #eee;"><strong>Total Energy:</strong></td>
                <td style="padding: 8px; border-bottom: 1px solid #eee;">${totalEnergy.toFixed(3)} ${totalEnergyUnit}</td>
              </tr>
              <tr>
                <td style="padding: 8px; border-bottom: 1px solid #eee;"><strong>Average Power:</strong></td>
                <td style="padding: 8px; border-bottom: 1px solid #eee;">${avgPower > 0 ? avgPower.toFixed(3) : avgEnergy.toFixed(3)} ${avgPower > 0 ? avgPowerUnit : avgEnergyUnit}</td>
              </tr>
              <tr>
                <td style="padding: 8px;"><strong>Peak Power:</strong></td>
                <td style="padding: 8px;">${peakPower.toFixed(3)} ${peakPowerUnit}</td>
              </tr>
            </table>
          </div>
        `;
      }

      case 'ConsumptionByRoom':
        if (!content.rooms || content.rooms.length === 0) {
          return `<div class="info-box"><p>No room data available.</p></div>`;
        }
        let roomsHtml = '<table style="width: 100%; border-collapse: collapse; margin-top: 10px;"><tr style="background: #f8f9fa;"><th style="padding: 8px; text-align: left;">Room</th><th style="padding: 8px; text-align: right;">Energy</th><th style="padding: 8px; text-align: right;">Avg Energy</th><th style="padding: 8px; text-align: right;">Peak Power</th></tr>';
        content.rooms.slice(0, 10).forEach(room => {
          const consumption = room.consumption || 0;
          const consumptionUnit = room.consumptionUnit || room.energyUnit || room.unit || 'kWh';
          const avgEnergy = room.averageEnergy || room.average || 0;
          const avgEnergyUnit = room.averageEnergyUnit || room.energyUnit || room.unit || 'kWh';
          const peak = room.peak || 0;
          const peakUnit = room.peakUnit || room.powerUnit || 'kW';
          roomsHtml += `<tr>
            <td style="padding: 8px; border-bottom: 1px solid #eee;">${room.roomName}</td>
            <td style="padding: 8px; text-align: right; border-bottom: 1px solid #eee;">${consumption.toFixed(3)} ${consumptionUnit}</td>
            <td style="padding: 8px; text-align: right; border-bottom: 1px solid #eee;">${avgEnergy.toFixed(3)} ${avgEnergyUnit}</td>
            <td style="padding: 8px; text-align: right; border-bottom: 1px solid #eee;">${peak.toFixed(3)} ${peakUnit}</td>
          </tr>`;
        });
        roomsHtml += '</table>';
        return `
          <div class="info-box">
            <h3 style="color: #214A59; margin-top: 0;">Consumption by Room</h3>
            ${roomsHtml}
          </div>
        `;

      case 'PeakLoads': {
        const peakPowerVal = content.peak || 0;
        const peakPowerUnitVal = content.peakUnit || content.powerUnit || content.unit || 'kW';
        const avgPowerVal = content.average || 0;
        const avgPowerUnitVal = content.averageUnit || content.powerUnit || content.unit || 'kW';
        return `
          <div class="info-box">
            <h3 style="color: #214A59; margin-top: 0;">Peak Loads</h3>
            <p><strong>Peak Power:</strong> ${peakPowerVal.toFixed(3)} ${peakPowerUnitVal}</p>
            <p><strong>Average Power:</strong> ${avgPowerVal.toFixed(3)} ${avgPowerUnitVal}</p>
            ${content.peakToAverageRatio ? `<p><strong>Peak to Average Ratio:</strong> ${content.peakToAverageRatio}x</p>` : ''}
          </div>
        `;
      }

      case 'MeasurementTypeBreakdown':
        if (!content.breakdown || content.breakdown.length === 0) {
          return `<div class="info-box"><p>No breakdown data available.</p></div>`;
        }
        let breakdownHtml = '<table style="width: 100%; border-collapse: collapse; margin-top: 10px;"><tr style="background: #f8f9fa;"><th style="padding: 8px; text-align: left;">Type</th><th style="padding: 8px; text-align: right;">Total</th><th style="padding: 8px; text-align: right;">Average</th></tr>';
        content.breakdown.forEach(item => {
          breakdownHtml += `<tr><td style="padding: 8px; border-bottom: 1px solid #eee;">${item.measurement_type}</td><td style="padding: 8px; text-align: right; border-bottom: 1px solid #eee;">${item.total} ${item.unit}</td><td style="padding: 8px; text-align: right; border-bottom: 1px solid #eee;">${item.average} ${item.unit}</td></tr>`;
        });
        breakdownHtml += '</table>';
        return `
          <div class="info-box">
            <h3 style="color: #214A59; margin-top: 0;">Measurement Type Breakdown</h3>
            ${breakdownHtml}
          </div>
        `;

      case 'EUI':
        if (!content.available) {
          return `<div class="info-box"><p>${content.message || 'EUI data not available'}</p></div>`;
        }
        return `
          <div class="info-box">
            <h3 style="color: #214A59; margin-top: 0;">Energy Use Intensity (EUI)</h3>
            <p><strong>EUI:</strong> ${content.eui} ${content.unit}</p>
            <p><strong>Total Consumption:</strong> ${content.totalConsumption} kWh</p>
            <p><strong>Heated Area:</strong> ${content.heatedArea} m²</p>
          </div>
        `;

      case 'PerCapitaConsumption':
        if (!content.available) {
          return `<div class="info-box"><p>${content.message || 'Per capita data not available'}</p></div>`;
        }
        return `
          <div class="info-box">
            <h3 style="color: #214A59; margin-top: 0;">Per Capita Consumption</h3>
            <p><strong>Per Capita:</strong> ${content.perCapita} ${content.unit}</p>
            <p><strong>Total Consumption:</strong> ${content.totalConsumption} kWh</p>
            <p><strong>Number of People:</strong> ${content.numPeople}</p>
          </div>
        `;

      case 'BenchmarkComparison':
        if (!content.available) {
          return `<div class="info-box"><p>${content.message || 'Benchmark comparison not available'}</p></div>`;
        }
        const statusColor = content.status === 'Below Target' ? '#28a745' : content.status === 'Above Target' ? '#dc3545' : '#ffc107';
        return `
          <div class="info-box">
            <h3 style="color: #214A59; margin-top: 0;">Benchmark Comparison</h3>
            <p><strong>Building EUI:</strong> ${content.buildingEUI} kWh/m²</p>
            <p><strong>Target EUI:</strong> ${content.targetEUI} kWh/m²</p>
            <p><strong>Difference:</strong> ${content.difference} kWh/m² (${content.percentageDifference}%)</p>
            <p><strong>Status:</strong> <span style="color: ${statusColor};">${content.status}</span></p>
            <p><strong>Type of Use:</strong> ${content.typeOfUse}</p>
          </div>
        `;

      case 'InefficientUsage':
        const baseLoad = content.baseLoad || 0;
        const baseLoadUnit = content.baseLoadUnit || content.energyUnit || 'kWh';
        const avgLoad = content.averageLoad || 0;
        const avgLoadUnit = content.averageLoadUnit || content.energyUnit || 'kWh';
        return `
          <div class="info-box">
            <h3 style="color: #214A59; margin-top: 0;">Inefficient Usage Analysis</h3>
            <p><strong>Base Energy Load:</strong> ${baseLoad.toFixed(3)} ${baseLoadUnit}</p>
            <p><strong>Average Energy Load:</strong> ${avgLoad.toFixed(3)} ${avgLoadUnit}</p>
            ${content.baseToAverageRatio ? `<p><strong>Base to Average Ratio:</strong> ${content.baseToAverageRatio}</p>` : ''}
            <p><strong>Status:</strong> ${content.inefficientUsageDetected ? '⚠️ ' + content.message : '✓ ' + content.message}</p>
          </div>
        `;

      case 'Anomalies':
        return `
          <div class="info-box">
            <h3 style="color: #214A59; margin-top: 0;">Anomalies Detected</h3>
            <p><strong>Total Anomalies:</strong> ${content.total}</p>
            <p><strong>By Severity:</strong> High: ${content.bySeverity.High}, Medium: ${content.bySeverity.Medium}, Low: ${content.bySeverity.Low}</p>
            ${content.anomalies && content.anomalies.length > 0 ? `
              <p><strong>Recent Anomalies:</strong></p>
              <ul>
                ${content.anomalies.slice(0, 5).map(anomaly => 
                  `<li>${new Date(anomaly.timestamp).toLocaleString()}: ${anomaly.sensorName} - ${anomaly.violatedRule} (${anomaly.severity})</li>`
                ).join('')}
              </ul>
            ` : ''}
          </div>
        `;

      case 'PeriodComparison':
        const currentConsumption = content.current.consumption || 0;
        const currentConsumptionUnit = content.current.consumptionUnit || content.current.energyUnit || 'kWh';
        const previousConsumption = content.previous.consumption || 0;
        const previousConsumptionUnit = content.previous.consumptionUnit || content.previous.energyUnit || 'kWh';
        const changeConsumption = content.change.consumption || 0;
        const changeConsumptionUnit = content.change.consumptionUnit || 'kWh';
        const currentPeak = content.current.peak || 0;
        const currentPeakUnit = content.current.peakUnit || content.current.powerUnit || 'kW';
        const previousPeak = content.previous.peak || 0;
        const previousPeakUnit = content.previous.peakUnit || content.previous.powerUnit || 'kW';
        const changePeak = content.change.peak || 0;
        const changePeakUnit = content.change.peakUnit || 'kW';
        return `
          <div class="info-box">
            <h3 style="color: #214A59; margin-top: 0;">Period Comparison</h3>
            <p><strong>Current Period Energy:</strong> ${currentConsumption.toFixed(3)} ${currentConsumptionUnit}</p>
            <p><strong>Previous Period Energy:</strong> ${previousConsumption.toFixed(3)} ${previousConsumptionUnit}</p>
            <p><strong>Energy Change:</strong> ${changeConsumption.toFixed(3)} ${changeConsumptionUnit} (${content.change.consumptionPercent !== null ? content.change.consumptionPercent.toFixed(1) : 'N/A'}%)</p>
            <p><strong>Current Peak Power:</strong> ${currentPeak.toFixed(3)} ${currentPeakUnit}</p>
            <p><strong>Previous Peak Power:</strong> ${previousPeak.toFixed(3)} ${previousPeakUnit}</p>
            <p><strong>Peak Power Change:</strong> ${changePeak.toFixed(3)} ${changePeakUnit}</p>
            ${content.change.consumptionPercent > 0 ? '<p style="color: #dc3545;">⚠️ Energy consumption increased</p>' : content.change.consumptionPercent < 0 ? '<p style="color: #28a745;">✓ Energy consumption decreased</p>' : '<p>No change</p>'}
          </div>
        `;

      case 'TimeBasedAnalysis':
        return `
          <div class="info-box">
            <h3 style="color: #214A59; margin-top: 0;">Time-Based Analysis</h3>
            <p><strong>Day Consumption:</strong> ${content.dayNight.day} kWh (${content.dayNight.dayPercentage}%)</p>
            <p><strong>Night Consumption:</strong> ${content.dayNight.night} kWh</p>
            <p><strong>Weekday Consumption:</strong> ${content.weekdayWeekend.weekday} kWh (${content.weekdayWeekend.weekdayPercentage}%)</p>
            <p><strong>Weekend Consumption:</strong> ${content.weekdayWeekend.weekend} kWh</p>
          </div>
        `;

      case 'BuildingComparison':
        if (!content.available) {
          return `<div class="info-box"><p>${content.message || 'Building comparison not available'}</p></div>`;
        }
        let buildingsHtml = '<table style="width: 100%; border-collapse: collapse; margin-top: 10px;"><tr style="background: #f8f9fa;"><th style="padding: 8px; text-align: left;">Building</th><th style="padding: 8px; text-align: right;">Consumption</th><th style="padding: 8px; text-align: right;">EUI</th></tr>';
        content.buildings.forEach(b => {
          buildingsHtml += `<tr><td style="padding: 8px; border-bottom: 1px solid #eee;">${b.buildingName}</td><td style="padding: 8px; text-align: right; border-bottom: 1px solid #eee;">${b.consumption} kWh</td><td style="padding: 8px; text-align: right; border-bottom: 1px solid #eee;">${b.eui !== null ? b.eui + ' kWh/m²' : 'N/A'}</td></tr>`;
        });
        buildingsHtml += '</table>';
        return `
          <div class="info-box">
            <h3 style="color: #214A59; margin-top: 0;">Building Comparison</h3>
            ${buildingsHtml}
          </div>
        `;

      case 'TemperatureAnalysis':
        if (!content.available) {
          return `<div class="info-box"><p>${content.message || 'Temperature analysis not available'}</p></div>`;
        }
        return `
          <div class="info-box">
            <h3 style="color: #214A59; margin-top: 0;">Temperature Analysis</h3>
            <p><strong>Overall Average:</strong> ${content.overall.average} ${content.overall.unit}</p>
            <p><strong>Overall Min:</strong> ${content.overall.min} ${content.overall.unit}</p>
            <p><strong>Overall Max:</strong> ${content.overall.max} ${content.overall.unit}</p>
            <p><strong>Total Sensors:</strong> ${content.totalSensors}</p>
          </div>
        `;

      case 'DataQualityReport':
        const qualityColor = content.status === 'Excellent' ? '#28a745' : content.status === 'Good' ? '#17a2b8' : content.status === 'Fair' ? '#ffc107' : '#dc3545';
        return `
          <div class="info-box">
            <h3 style="color: #214A59; margin-top: 0;">Data Quality Report</h3>
            <p><strong>Average Quality:</strong> <span style="color: ${qualityColor};">${content.averageQuality}%</span></p>
            <p><strong>Status:</strong> <span style="color: ${qualityColor};">${content.status}</span></p>
            <p>${content.message}</p>
          </div>
        `;

      default:
        return `<div class="info-box"><p>Content type: ${contentType}</p></div>`;
    }
  }

  /**
   * Format content section as plain text
   */
  formatContentSectionText(contentType, content) {
    // Simplified text version - can be enhanced
    let text = `\n${contentType.toUpperCase()}\n`;
    text += `${'-'.repeat(30)}\n`;
    
    if (content.available === false) {
      text += `${content.message || 'Data not available'}\n`;
      return text;
    }

    switch (contentType) {
      case 'TotalConsumption':
        const totalEnergy = content.totalConsumption || 0;
        const totalEnergyUnit = content.totalConsumptionUnit || content.energyUnit || 'kWh';
        const avgPower = content.averagePower || 0;
        const avgPowerUnit = content.averagePowerUnit || content.powerUnit || 'kW';
        const avgEnergy = content.averageEnergy || content.average || 0;
        const avgEnergyUnit = content.averageEnergyUnit || content.energyUnit || 'kWh';
        const peakPower = content.peak || 0;
        const peakPowerUnit = content.peakUnit || content.powerUnit || 'kW';
        text += `Total Energy: ${totalEnergy.toFixed(3)} ${totalEnergyUnit}\n`;
        text += `Average Power: ${(avgPower > 0 ? avgPower : avgEnergy).toFixed(3)} ${avgPower > 0 ? avgPowerUnit : avgEnergyUnit}\n`;
        text += `Peak Power: ${peakPower.toFixed(3)} ${peakPowerUnit}\n`;
        break;
      case 'ConsumptionByRoom':
        if (content.rooms) {
          content.rooms.slice(0, 10).forEach(room => {
            text += `${room.roomName}: ${room.consumption} ${room.unit}\n`;
          });
        }
        break;
      case 'EUI':
        if (content.available) {
          text += `EUI: ${content.eui} ${content.unit}\n`;
        }
        break;
      case 'Anomalies':
        text += `Total: ${content.total}\n`;
        text += `High: ${content.bySeverity.High}, Medium: ${content.bySeverity.Medium}, Low: ${content.bySeverity.Low}\n`;
        break;
      default:
        text += JSON.stringify(content, null, 2) + '\n';
    }
    
    return text + '\n';
  }
}

module.exports = new ReportEmailService();
