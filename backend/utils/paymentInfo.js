const getOpenOperationalDay = async (pool) => {
  try {
    const { rows } = await pool.query(
      `SELECT op_date FROM operational_days WHERE status = 'open' ORDER BY opened_at DESC NULLS LAST, op_date DESC LIMIT 1`
    );
    if (!rows.length || !rows[0].op_date) {
      // Если открытых дней нет, берем последний закрытый
      const { rows: closedRows } = await pool.query(
        `SELECT op_date FROM operational_days WHERE status = 'closed' ORDER BY op_date DESC LIMIT 1`
      );
      if (closedRows.length && closedRows[0].op_date) {
        const d = new Date(closedRows[0].op_date);
        return d.getFullYear() + '-' + String(d.getMonth() + 1).padStart(2, '0') + '-' + String(d.getDate()).padStart(2, '0');
      }
      return null;
    }
    const d = new Date(rows[0].op_date);
    // Используем локальные компоненты даты, чтобы избежать сдвига из-за часового пояса
    return d.getFullYear() + '-' + String(d.getMonth() + 1).padStart(2, '0') + '-' + String(d.getDate()).padStart(2, '0');
  } catch (e) {
    console.error('getOpenOperationalDay error:', e);
    return null;
  }
};

const getPaymentInfo = async (pool, loanId, targetDate = null) => {
  const opDateFromDb = await getOpenOperationalDay(pool);
  const dateStr = targetDate || opDateFromDb || new Date().toISOString().slice(0, 10);
  const round2 = (value) => Math.round((Number(value) || 0) * 100) / 100;

  const { rows: loanBalRows } = await pool.query(`SELECT * FROM loans WHERE loan_id::text = $1::text`, [loanId]);
  if (!loanBalRows.length) throw new Error('Займ не найден');
  const l = loanBalRows[0];
  const principalBalance = Number(l.principal_balance || 0);

  const rateAnnualRaw = Number(l.interest_rate_annual || 0);
  const rateFn = rateAnnualRaw > 1 ? (rateAnnualRaw / 100) : rateAnnualRaw;
  const dRate = rateFn / 365;
  
  const opDateDt = new Date(`${dateStr}T12:00:00`);
  if (isNaN(opDateDt.getTime())) {
    throw new Error(`Некорректная дата операции: ${dateStr}`);
  }
  const year = opDateDt.getFullYear();
  const month = opDateDt.getMonth();

  const firstDayOfCurrentMonth = new Date(year, month, 1, 12, 0, 0);
  const endOfCurrentMonth = new Date(year, month + 1, 0, 12, 0, 0);
  const checkpointDt = new Date(2026, 3, 1, 12, 0, 0); // 01.04.2026

  const daysBetween = (a, b) => {
    const ta = a instanceof Date ? a.getTime() : Number(a);
    const tb = b instanceof Date ? b.getTime() : Number(b);
    if (isNaN(ta) || isNaN(tb)) return 0;
    return Math.round((tb - ta) / (1000 * 3600 * 24));
  };
  const minDate = (a, b) => a <= b ? a : b;

  const { rows: moveRows } = await pool.query(
    `SELECT transaction_date, amount, transaction_type 
     FROM transactions 
     WHERE loan_id::text = $1::text 
       AND transaction_date >= $2::date
       AND transaction_date <= $3::date
       AND transaction_type IN ('Выдача', 'Погашение (Тело)')
       AND (is_deleted = FALSE OR is_deleted IS NULL)`,
    [loanId, checkpointDt.toISOString().slice(0,10), endOfCurrentMonth.toISOString().slice(0, 10)]
  );

  let intBeforeThisMonth = 0;
  let intWithinThisMonthToday = 0;
  let intWithinThisMonthFull = 0;

  let runningBal = principalBalance;
  let currentTime = endOfCurrentMonth; 

  const calcInterest = (start, end, bal) => {
      const d = daysBetween(start, end);
      if (d <= 0) return 0;
      return bal * dRate * d;
  };

  const addInterest = (start, end, bal) => {
      if (daysBetween(start, end) <= 0) return;
      if (end <= firstDayOfCurrentMonth) {
          intBeforeThisMonth += calcInterest(start, end, bal);
      } else if (start >= firstDayOfCurrentMonth) {
          const endToday = minDate(end, opDateDt);
          intWithinThisMonthToday += calcInterest(start, endToday, bal);
          intWithinThisMonthFull += calcInterest(start, end, bal);
      } else {
          intBeforeThisMonth += calcInterest(start, firstDayOfCurrentMonth, bal);
          const endToday = minDate(end, opDateDt);
          intWithinThisMonthToday += calcInterest(firstDayOfCurrentMonth, endToday, bal);
          intWithinThisMonthFull += calcInterest(firstDayOfCurrentMonth, end, bal);
      }
  };

  const sortedMoves = moveRows.sort((a,b) => new Date(b.transaction_date) - new Date(a.transaction_date));

  for (const move of sortedMoves) {
      const moveDate = new Date(`${String(move.transaction_date).slice(0, 10)}T12:00:00`);
      if (moveDate < currentTime) {
          const start = moveDate > checkpointDt ? moveDate : checkpointDt;
          addInterest(start, currentTime, runningBal);
          currentTime = start;
      }
      if (move.transaction_type === 'Выдача') runningBal -= Number(move.amount);
      else runningBal += Number(move.amount);
  }
  
  if (checkpointDt < currentTime) {
      addInterest(checkpointDt, currentTime, runningBal);
      const oneDayInt = runningBal * dRate * 1;
      intWithinThisMonthToday += oneDayInt;
      intWithinThisMonthFull += oneDayInt;
  }

  const { rows: schedOverdueIntRows } = await pool.query(
    `SELECT COALESCE(SUM(interest_amount), 0) as overdue_int
     FROM loan_schedules 
     WHERE loan_id::text = $1::text AND payment_date <= $2::date AND is_paid = FALSE AND (is_deleted IS NOT TRUE)`,
    [loanId, dateStr]
  );
  const scheduledOverdueInt = Number(schedOverdueIntRows[0]?.overdue_int || 0);

  const { rows: paidNowRows } = await pool.query(
    `SELECT COALESCE(SUM(amount), 0) as int_paid FROM transactions 
     WHERE loan_id::text = $1::text AND transaction_type = 'Погашение (%)' AND (is_deleted IS NOT TRUE)`,
    [loanId]
  );
  const interestPaidOverall = Number(paidNowRows[0]?.int_paid || 0);

  const baselineDB = Number(l.overdue_interest || 0);
  console.log(`[Calc DEBUG] loan_id: ${loanId}, baselineDB: ${baselineDB}, intBeforeThisMonth: ${intBeforeThisMonth}, interestPaidOverall: ${interestPaidOverall}`);
  let intRed = 0;
  if (scheduledOverdueInt > 0) {
      intRed = round2(scheduledOverdueInt);
      console.log(`[Calc DEBUG] Using scheduledOverdueInt: ${intRed}`);
  } else {
      intRed = round2(Math.max(0, baselineDB + intBeforeThisMonth - interestPaidOverall));
      console.log(`[Calc DEBUG] Calculated intRed via baseline: ${intRed}`);
      const { rows: firstSched } = await pool.query(
        `SELECT MIN(payment_date) as md FROM loan_schedules WHERE loan_id::text = $1::text`, [loanId]
      );
      if (firstSched[0]?.md && new Date(firstSched[0].md) > opDateDt) {
          console.log(`[Calc DEBUG] First schedule in future (${firstSched[0].md} > ${dateStr}), resetting intRed to 0`);
          intRed = 0;
      }
  }

  const intToday = round2(Math.max(0, intWithinThisMonthToday - Math.max(0, interestPaidOverall - (scheduledOverdueInt > 0 ? scheduledOverdueInt : (baselineDB + intBeforeThisMonth)))));
  const intEOM = round2(Math.max(0, intWithinThisMonthFull - Math.max(0, interestPaidOverall - (scheduledOverdueInt > 0 ? scheduledOverdueInt : (baselineDB + intBeforeThisMonth)))));
  
  const { rows: paidPenRow } = await pool.query(
    `SELECT COALESCE(SUM(amount), 0) as paid FROM transactions WHERE loan_id::text = $1::text AND transaction_type = 'Погашение пени'`, [loanId]
  );
  const penaltyPaidOverall = Number(paidPenRow[0]?.paid || 0);
  const baseAccruedPen = Number(l.accrued_penalty || 0);

  const lastDayOfPrevMonth = new Date(year, month, 0, 12, 0, 0);
  const { rows: scheduledMonthRow } = await pool.query(
    `SELECT SUM(principal_amount) as principal_due
     FROM loan_schedules 
     WHERE loan_id::text = $1::text 
       AND payment_date > $2::date 
       AND payment_date <= $3::date
       AND (is_deleted = FALSE OR is_deleted IS NULL)`,
    [loanId, lastDayOfPrevMonth.toISOString().slice(0,10), endOfCurrentMonth.toISOString().slice(0,10)]
  );
  const principalDueThisMonth = Number(scheduledMonthRow[0]?.principal_due || 0);

  const { rows: overdueInfo } = await pool.query(
    `SELECT 
       MIN(payment_date) as earliest_unpaid_date,
       COALESCE(SUM(principal_amount), 0) - (SELECT COALESCE(SUM(amount), 0) FROM transactions WHERE loan_id::text = $1::text AND transaction_type = 'Погашение (Тело)' AND (is_deleted = FALSE OR is_deleted IS NULL)) as overdue_principal_calc
     FROM loan_schedules 
     WHERE loan_id::text = $1::text AND payment_date <= $2::date AND is_paid = FALSE AND (is_deleted = FALSE OR is_deleted IS NULL)`,
    [loanId, dateStr]
  );
  let earliestUnpaid = overdueInfo[0]?.earliest_unpaid_date || l.overdue_since;
  
  if (!earliestUnpaid && intRed > 1) {
      const { rows: firstDateEver } = await pool.query(
        `SELECT MIN(payment_date) as md FROM loan_schedules WHERE loan_id::text = $1::text`,
        [loanId]
      );
      earliestUnpaid = firstDateEver[0]?.md || checkpointDt.toISOString().slice(0,10);
  }
  
  earliestUnpaid = earliestUnpaid || dateStr;
  const overduePrincipal = Math.max(0, Number(overdueInfo[0]?.overdue_principal_calc || 0));

  const safeDateStr = (d) => {
      if (!d) return dateStr;
      const s = String(d);
      if (s.length < 10) return dateStr;
      return s.slice(0, 10);
  };

  const startOverdueDt = new Date(`${safeDateStr(earliestUnpaid)}T12:00:00`);
  const totalOverdueDays = Math.max(0, daysBetween(startOverdueDt, opDateDt));
  
  let ratePerDay = 0;
  const pRateAnnualRaw = Number(l.penalty_rate_annual || l.interest_rate_annual || 0);
  const pRateFn = pRateAnnualRaw > 1 ? (pRateAnnualRaw / 100) : pRateAnnualRaw;
  const pRatePerDay = pRateFn / 365;

  if (l.penalty_type === 'daily') {
      ratePerDay = Number(l.penalty_rate_daily || 0) / 100;
  } else {
      ratePerDay = pRatePerDay;
  }
  
  let livePenalty = 0;
  const hasScheduleOverdue = !!overdueInfo[0]?.earliest_unpaid_date;

  if (!hasScheduleOverdue && baselineDB > 0 && totalOverdueDays > 0) {
      let penCursor = new Date(startOverdueDt);
      let runBase = overduePrincipal + baselineDB;

      while (penCursor < opDateDt) {
          const py = penCursor.getFullYear();
          const pm = penCursor.getMonth();
          const monthEnd = new Date(py, pm + 1, 0, 12, 0, 0);
          const segEnd = monthEnd < opDateDt ? monthEnd : opDateDt;
          const segDays = daysBetween(penCursor, segEnd);

          if (segDays > 0) {
              livePenalty += runBase * ratePerDay * segDays;
          }

          if (monthEnd < opDateDt) {
              const daysInMonth = monthEnd.getDate();
              const monthInt = principalBalance * dRate * daysInMonth;
              runBase += monthInt;
          }

          if (segEnd <= penCursor) {
              penCursor = new Date(py, pm + 1, 1, 12, 0, 0);
          } else {
              penCursor = segEnd;
          }
      }
      livePenalty = round2(livePenalty);
  } else if (totalOverdueDays > 0) {
      const penaltyBaseAmount = overduePrincipal + (intRed > 0 ? intRed : 0);
      livePenalty = round2(penaltyBaseAmount * ratePerDay * totalOverdueDays);
  }

  const basePenalty = Math.max(0, round2(baseAccruedPen + livePenalty - penaltyPaidOverall));

  return {
    loan_id: loanId,
    calculated_at: dateStr,
    end_of_month: endOfCurrentMonth.toISOString().slice(0,10),
    is_overdue: (intRed > 0.01 || overduePrincipal > 0.01 || basePenalty > 0.01),
    balance_od: principalBalance,
    next_payment_date: earliestUnpaid,
    od_col1_overdue: overduePrincipal,
    od_col2_scheduled: principalDueThisMonth,
    od_col3_full: principalBalance,
    int_col1: intRed, 
    int_col2: round2(intRed + intEOM), 
    int_col3: round2(intRed + intToday), 
    pen_col1: basePenalty,
    pen_col2: basePenalty,
    pen_col3: basePenalty,
    total_col1: round2(overduePrincipal + intRed + basePenalty),
    total_col2: round2(principalDueThisMonth + intRed + intEOM + basePenalty),
  };
};

module.exports = { getPaymentInfo };

module.exports = { getPaymentInfo };
